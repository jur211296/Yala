#!/bin/bash
# Copia de perfilado: Release-Dev optimizada con DEBUG solo en la copia.
# Uso: perfil.sh <etiqueta> <tree-ish | dir>
set -e
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-27-eficiencia-7-foto-widgets-y-arranque/b263046f-8705-4b85-8438-6596fc864dd3/scratchpad
W=/Users/max-jur/Claude/worktrees/Yala-2026-11-27-eficiencia-7-foto-widgets-y-arranque
C=$S/copia
mkdir -p $C
if [ -d "$2" ]; then
  rsync -a --delete --exclude .git --exclude DerivedData --exclude build --exclude 'docs/' --exclude marketing --exclude Web "$2"/ $C/
else
  rm -rf $C.new; mkdir -p $C.new
  (cd $W && git archive "$2" -- . ':!docs' ':!marketing' ':!Web') | tar -x -C $C.new
  rsync -a --delete --checksum $C.new/ $C/; rm -rf $C.new
  (cd $W && find . -type l -not -path './.git/*' -not -path './docs/*' | while read l; do cp -L "$l" "$C/$l"; done)
fi
python3 - "$C/Yala.xcodeproj/project.pbxproj" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
viejo='SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEV_BUILD $(inherited)";'
assert s.count(viejo)==1, s.count(viejo)
s=s.replace(viejo,'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG DEV_BUILD $(inherited)";')
open(p,'w').write(s)
PY
cd $C
set +e
xcodebuild -project Yala.xcodeproj -scheme "Yala Dev" -configuration Release-Dev -destination 'generic/platform=iOS' \
  -derivedDataPath $S/dd -allowProvisioningUpdates -jobs 2 build > $S/build-$1.log 2>&1
E=$?; echo "BUILD EXIT $E"; [ $E = 0 ] || { grep -E "error:" $S/build-$1.log | head; exit 1; }
APP=$(ls -d $S/dd/Build/Products/Release-Dev-iphoneos/*.app | head -1)
rm -rf $S/app-$1.app; cp -R "$APP" $S/app-$1.app
echo "APP $S/app-$1.app"
