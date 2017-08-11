#! /bin/bash
pushd src/ 2>&1 >/dev/null
rm ../build.zip 2>&1 >/dev/null
zip -r ../build.zip * 2>&1 >/dev/null
popd 2>&1 >/dev/null
echo '{"path" : "build.zip"}'