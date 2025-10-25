#!/usr/bin/env bash

MODEL=""
RESOURCE=""
API_KEY=""
OPENAI="https://api.openai.com/v1/responses"

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            case $2 in
                "gpt-4.1-mini")
                    MODEL="$2"
                    RESOURCE="$OPENAI"
                    API_KEY="$OPENAI_API_KEY"
                ;;
                "gpt-4.1-nano")
                    MODEL="$2"
                    RESOURCE=$OPENAI
                    API_KEY="$OPENAI_API_KEY"
                ;;
                *)
                    echo "Unknown model: $2"
                    exit 1
                ;;
            esac
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$MODEL" ]]; then
    MODEL="gpt-4.1-nano"
    RESOURCE=$OPENAI
    API_KEY="$OPENAI_API_KEY"
fi

echo "Hello, how can I help?"

read -r QUESTION

RESPONSE=$(curl --silent $RESOURCE \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{\"model\": \"$MODEL\", \"input\": \"$QUESTION\"}")

echo "$RESPONSE" | jq -r '.output[0].content[0].text'

