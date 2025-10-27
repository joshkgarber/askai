#!/usr/bin/env bash

MODEL=""
PROVIDER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            case $2 in
                "gpt-4.1-mini")
                    MODEL="$2"
                    PROVIDER="openai"
                ;;
                "gpt-4.1-nano")
                    MODEL="$2"
                    PROVIDER="openai"
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
    PROVIDER="openai"
fi

echo "Hello, how can I help?"
read -r QUESTION

openai_request() {
    local response=$(curl --silent https://api.openai.com/v1/responses \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "{\"model\": \"$MODEL\", \"input\": \"$QUESTION\"}")
    echo "$response" | jq -r '.output[0].content[0].text'
}

RESPONSE=""
case $PROVIDER in
    "openai")
        RESPONSE=$(openai_request)
        ;;
    *)
        echo "Unknown provider: $PROVIDER"
        exit 1
        ;;
esac

echo "$RESPONSE"

