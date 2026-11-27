#!/bin/bash
# Copia de perfilado: Release-Dev optimizada con DEBUG solo en la copia (mismo método que el informe y el lote 4).
# Uso: perfil.sh <etiqueta> <árbol fuente> <scratch>
set -e
W=$2; S=$3; C=$S/copia-$1
mkdir -p $C
rsync -a --delete --exclude .git --exclude DerivedData --exclude build --exclude 'docs/' --exclude marketing --exclude Web $W/ $C/
python3 - "$C/Yala.xcodeproj/project.pbxproj" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
viejo='SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEV_BUILD $(inherited)";'
assert s.count(viejo)==1, s.count(viejo)
s=s.replace(viejo,'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG DEV_BUILD $(inherited)";')
open(p,'w').write(s)
PY
cd $C
xcodebuild -project Yala.xcodeproj -scheme "Yala Dev" -configuration Release-Dev -destination 'generic/platform=iOS' \
  -derivedDataPath $S/dd-perfil -allowProvisioningUpdates -jobs 2 build > $S/build-$1.log 2>&1
echo "BUILD EXIT $?"
APP=$(ls -d $S/dd-perfil/Build/Products/Release-Dev-iphoneos/*.app | head -1)
rm -rf $S/app-$1.app; cp -R "$APP" $S/app-$1.app
echo "APP $S/app-$1.app"
