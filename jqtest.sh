#!/usr/bin/env bash

name="Josh
Garber"
age=35
description='I `am` $a "programmer" person'
# json=$(jq -n --arg name "$name" --arg description "$description" --argjson age "$age" '{name: $name, age: $age}')
json=$(jq -n --arg name "$name" --arg description "$description" --argjson age "$age" '{name: $name, description: $description, age: $age}')
echo "$json"
