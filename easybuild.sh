#!/bin/bash -e
# All-in-one script to easily create a Dockerfile and build an image to build any package in docker
# and to create the neccessary Dockerfiles and build scripts with the right dependencies - and to make finding them easier
# - without cluttering your host system with unnecessary packages or build tools
# you can keep editing this file and rerun it after every change... rm -rf src if you want to start build from scratch
# Ubuntu version
# todo: script to watch & run on changes; clean up docker images if successful; package binaries; other platforms?.. 
# ...how about updating the build systems eg making ./configure package- and docker aware...?
#
# Synergy2 1.8.8 todo: upgrade libssl

[[ ! -z $1 ]] && { Y="-$1"; } # first parameter is easybuild-imagename # fixme consider using the current directory name
                              # then the workflow would be to copy just easybuild.sh and code tar files to a new directory 
                              # to use it in other projects. Alternatively use the script name, then it can just be copied and edited

# Log output
exec 1> >(tee -a log.easybuild) 2> >(tee -a err.easybuild 2>&1)  # these don't clutter autocompletion.
echo -e "\n\n--- Easybuild at `date` ---" | tee /dev/stderr

which docker >/dev/null||(echo Install docker first: sudo apt-get install docker.io; exit)
D="sudo docker"; docker ps -aq 2>/dev/null && D="docker"

# you can change the dependencies here -------------------------------------------
A="build-essential cmake libcurl4-gnutls-dev libxi-dev libxkbcommon-x11-dev libxtst-dev libxrandr-dev libxinerama-dev unzip" 
# libssl-dev # needs some code changes

CPUS=`grep -c ^processor /proc/cpuinfo`; [ $CPUS -gt 1 ] && M=-j$CPUS 

# this just either apt gets everything in one line, or in separate lines (for quicker package-finding by utilizing docker caches)
G="DEBIAN_FRONTEND=noninteractive apt-get install -y"; L="   "; E="\ "; H=" && $G \\" 
#CPUS=1; C=""; L="RUN $G"; E=""; Y="$Y-dockerhub"; H="# fixme" # comment out this line to make a portable Dockerfile suitable for dockerhub, after you've found all the dependencies
for B in $A; do 
  C=$(cat <<END
$C 
$L $B    $E

END
); done
CC=${C::${#C}-3} # Remove the last "  \" if it's present, to please those silly docker devs, bash required

[ -e easybuild.sh ] || cd `dirname "$0"` || (echo Please run this from the $0 script directory itself;exit)

F=v1.8.8-stable.tar.gz
I=easybuild$Y

echo Building image... # you can change the dockerfile here ---------------------- static part
tee Dockerfile <<END
FROM ubuntu
RUN apt-get update $H $CC
CMD /usr/src/inside-docker.sh

END
$D build -t $I - < Dockerfile

echo Setting up src/
[[ -e src ]] || mkdir src
cp -v $F src/ # you can change the build script here  ---------------------------- dynamic part, if you rm -rf src/ # remove -e to be more lenient
cat > src/inside-docker.sh <<EOF
#!/bin/bash -e
cd /usr/src 
[ -e target ] || { mkdir target && tar -zxvf $F -C target; }
cd target/*
echo Building openssl-1.0.2
echo ================ THIS VERSION OF OPENSSL IS INSECURE RATHER PATCH THE CODE FOR NEWER SSL ==========================
echo If it fails, just re-run $0
sleep 3
[ -e ext/openssl ] || (cd ext; for a in gmock-1.6.0 gtest-1.6.0; do unzip -o \$a.zip -d \$a; done; for a in *.tar.gz; do tar -zxvf \$a; done; ln -s openssl-1.0.2 openssl; rm openssl/Makefile)
(cd ext/openssl; [ -e Makefile ] || (./config && make clean && make $M); cp lib* /usr/local/lib || (make $M; cp lib* /usr/local/lib); ln -s \`pwd\`/include/openssl /usr/local/include || : )
sed -i 's@ssl crypto)@ssl crypto dl)@' src/CMakeLists.txt # patch
./configure && make $M
strip /usr/src/target/afzaalace-synergy-stable-builds-c30301e/bin/*
EOF
chmod +x src/inside-docker.sh
echo Running temporary container... # if you get an error, remove the --init
D="$D run --rm --init -it -v `pwd`/src:/usr/src $I"
$D

echo Done!
echo src/target/*/bin
ls -l src/target/*/bin/
shasum src/target/*/bin/*

echo Making the container interactive...
cp src/inside-docker.sh src/build.sh
echo /bin/bash > src/inside-docker.sh
echo To inspect: $D
echo To clean up: docker rmi $I

