#!/usr/bin/env bash

show_usage() {
  echo ""
  echo -e "\033[1;32mUsage:\033[0m $0 [OPTIONS]"
  echo ""
  echo -e "\033[1;32mOptions:\033[0m"
  echo -e "  \033[1m--help\033[0m                   show this help text"
  echo -e "  \033[1m-m --model\033[0m <model>       choose a model"
  echo -e "  \033[1m-i --instruct\033[0m <string>   set system instructions"
  echo ""
  echo -e "\033[1;32mModels:\033[0m"
  echo -e "  \033[1mmini\033[0m    OpenAI ChatGPT 4.1 mini"
  echo -e "  \033[1mnano\033[0m    OpenAI ChatGPT 4.1 nano"
  echo -e "  \033[1mhaiku\033[0m   Anthropic Claude 4.5 haiku"
  echo ""
  echo -e "The defalt model is \033[1mnano\033[0m"
}

MODEL=""
PROVIDER=""
SYSTEM_INSTRUCTION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--model)
      case $2 in
        "mini")
          MODEL="gpt-4.1-mini"
          PROVIDER="openai"
        ;;
        "nano")
          MODEL="gpt-4.1-nano"
          PROVIDER="openai"
        ;;
        "haiku")
          MODEL="claude-haiku-4-5"
          PROVIDER="anthropic"
        ;;
        *)
          echo "Unknown model alias: $2"
          exit 1
        ;;
      esac
      shift 2
      ;;
    -i|--instruct)
      if [[ -z "$2" ]]; then
        echo "Missing system instruction string argument."
        exit 1
      fi
      SYSTEM_INSTRUCTION="$2"
      shift 2
      ;;
    --help)
      show_usage
      exit 0
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
    -d "{\"model\": \"$MODEL\", \"input\": \"$QUESTION\", \"instructions\": \"$SYSTEM_INSTRUCTION\"}")
  echo "$response" | jq -r '.output[0].content[0].text'
}

anthropic_request() {
	local response=$(curl --silent https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
          \"model\": \"$MODEL\",
          \"max_tokens\": 1000,
          \"system\": \"$SYSTEM_INSTRUCTION\",
          \"messages\": [
            {
              \"role\": \"user\",
              \"content\": \"$QUESTION\"
            }
          ]
        }"
  )
	echo "$response" | jq -r '.content[0].text'
}

RESPONSE=""
case $PROVIDER in
  "openai")
    RESPONSE=$(openai_request)
    ;;
  "anthropic")
    RESPONSE=$(anthropic_request)
    ;;
  *)
    echo "Unknown provider: $PROVIDER"
    exit 1
    ;;
esac

echo "$RESPONSE"

