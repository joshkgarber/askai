#!/usr/bin/env bash

echo "Hello, how can I help?"

read -r QUESTION

ANSWER=$(curl --silent https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{\"model\": \"gpt-4.1-nano\", \"input\": \"$QUESTION\"}" \
    | jq -r '.output[0].content[0].text')

echo $ANSWER

