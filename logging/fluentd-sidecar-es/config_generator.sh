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

if [ ! ${#filepaths[@]} -eq ${#containers[@]} ]
then
  echo "ERROR: The number of containers is different from the number of files to collect."
fi

declare -A names_count

function get_uncollided_name {
  next_name=$1
  base_name=$1
  while [ ${names_count[$next_name]} ];
  do
    ((names_count[$base_name]++))
    next_name=${base_name}_${names_count[$base_name]}
  done
  names_count+=([$next_name]=1)
}

for i in ${!filepaths[*]}
do
  filename=$(basename ${filepaths[i]})
  get_uncollided_name $filename
  filename=$next_name
  cat > "/etc/td-agent/files/${filename}" << EndOfMessage
<source>
  type tail
  format none
  message_key log
  time_key time
  path ${filepaths[i]}
  pos_file /etc/td-agent/fluentd-es.log.pos
  time_format %Y-%m-%dT%H:%M:%S
  tag kubernetes.${containers[i]}.${POD_NAME}_${NAMESPACE_NAME}_${containers[i]}.*
  read_from_head true
</source>

<filter kubernetes.${containers[i]}.**>
@type record_transformer
  enable_ruby true
  auto_typecast true
  <record>
    kubernetes \${{"file" => "\${tag_suffix[-2]}", "pod_name" => "$POD_NAME", "namespace_name" => "$NAMESPACE_NAME", "container_name" => "${containers[i]}"}}
  </record>
</filter>
EndOfMessage
done

if [ -z "$FILES_TO_ROTATE" ] || [ -z "$SIZE_LIMIT" ] || [ -z "$ROTATE_TIMES" ]; then
  exit 0
fi
read -ra files_to_rotate <<<"$FILES_TO_ROTATE"
read -ra size_limit <<<"$SIZE_LIMIT"
read -ra rotate_times <<<"$ROTATE_TIMES"

if [ ${#files_to_rotate[@]} -eq ${#size_limit[@]} ] && [ ${#files_to_rotate[@]} -eq ${#rotate_times[@]} ]; then
  for i in ${!files_to_rotate[*]}
  do
    cat >> "/etc/logrotate.conf" << EndOfMessage
${files_to_rotate[i]} {
  size ${size_limit[i]}
  rotate ${rotate_times[i]}
}
EndOfMessage
  done
fi
