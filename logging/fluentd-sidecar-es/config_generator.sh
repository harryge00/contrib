#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

mkdir -p /etc/td-agent/files
if [ -z "$FILES_TO_COLLECT" ]; then
  exit 0
fi

read -ra filepaths <<< $FILES_TO_COLLECT
read -ra containers <<< $CONTAINERS

for i in ${!arr1[*]}
do
  echo $i
  echo ${arr1[i]} ${arr2[i]}
done

if [ ! ${#filepaths[@]} -eq ${#containers[@]} ]
then
  echo "ERROR: The number of containers is different from the number of files to collect."
fi
for i in ${!filepaths[*]}
do
  filename=$(basename ${filepaths[i]})
  # dir=$(dirname $filepath)
  # tag="file`echo $dir|sed 's/\//\./g'`.*"
  cat > "/etc/td-agent/files/${filename}" << EndOfMessage
<source>
  type tail
  format none
  message_key log
  time_key time
  path ${filepaths[i]}
  pos_file /etc/td-agent/fluentd-es.log.pos
  time_format %Y-%m-%dT%H:%M:%S
  tag kubernetes.${containers[i]}.${POD_NAME}_${NAMESPACE_NAME}_${containers[i]}
  read_from_head true
</source>

<filter kubernetes.${containers[i]}.**>
@type record_transformer
  enable_ruby true
  auto_typecast true
  <record>
    kubernetes \${{"pod_name" => "$POD_NAME", "namespace_name" => "$NAMESPACE_NAME", "container_name" => "${containers[i]}"}}
  </record>
</filter>
EndOfMessage
done
