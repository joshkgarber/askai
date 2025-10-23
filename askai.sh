#!/usr/bin/env bash

MODEL="gpt-4.1-nano"

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Hello, how can I help?"

read -r QUESTION

ANSWER=$(curl --silent https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{\"model\": \"$MODEL\", \"input\": \"$QUESTION\"}" \
    | jq -r '.output[0].content[0].text')

echo "$ANSWER"

