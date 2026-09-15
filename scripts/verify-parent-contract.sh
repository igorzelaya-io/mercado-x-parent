#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
consumer_pom="${repository_root}/tests/consumer-contract/pom.xml"
effective_pom="${repository_root}/tests/consumer-contract/target/effective-pom.xml"

mvn -B -ntp -f "${consumer_pom}" clean compile \
  help:effective-pom -Doutput="${effective_pom}"

python3 - "${effective_pom}" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

effective_pom = Path(sys.argv[1])
namespace = {"m": "http://maven.apache.org/POM/4.0.0"}
root = ET.parse(effective_pom).getroot()

dependencies = root.findall("./m:dependencies/m:dependency", namespace)
coordinates = {
    (
        dependency.findtext("m:groupId", default="", namespaces=namespace),
        dependency.findtext("m:artifactId", default="", namespaces=namespace),
    )
    for dependency in dependencies
}
expected = {("org.mapstruct", "mapstruct")}

if coordinates != expected:
    inherited = ", ".join(f"{group}:{artifact}" for group, artifact in sorted(coordinates))
    raise SystemExit(
        "Thin-parent contract failed: the consumer should contain only its explicit "
        f"MapStruct dependency, but resolved [{inherited}]"
    )

mapstruct = dependencies[0]
version = mapstruct.findtext("m:version", default="", namespaces=namespace)
if version != "1.6.3":
    raise SystemExit(
        f"Managed MapStruct version should resolve to 1.6.3, but resolved {version!r}"
    )

print("Thin-parent contract passed: no application dependencies were inherited.")
print(f"Managed MapStruct version resolved to {version}.")
PY

generated_mapper="${repository_root}/tests/consumer-contract/target/generated-sources/annotations/contract/ContractMapperImpl.java"
if [[ ! -f "${generated_mapper}" ]]; then
  echo "Thin-parent contract failed: MapStruct implementation was not generated." >&2
  exit 1
fi

echo "Annotation processor contract passed: ContractMapperImpl was generated."
