R=v1.8.8-stable
for F in $R.tar.gz $R-Windows-x64.msi $R-Windows-x86.msi $R-MacOSX-x86_64.dmg $R-Linux-x86_64.rpm $R-Linux-x86_64.deb $R-Linux-i686.rpm $R-stable-Linux-i686.deb $R.zip; do 
[ -e $F ] || wget "https://sourceforge.net/projects/synergy-stable-builds/files/$R/$F/download" -O $F
ls -l $F
done
