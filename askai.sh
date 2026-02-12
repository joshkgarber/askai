#!/usr/bin/env bash

show_usage() {
  echo ""
  echo -e "\033[1;32mUsage:\033[0m $0 [OPTIONS]"
  echo ""
  echo -e "\033[1;32mOptions:\033[0m"
  echo -e "  \033[1m--help\033[0m                     show this help text"
  echo -e "  \033[1m-m --model\033[0m <model>         choose a model (default: \033[1mnano\033[0m)"
  echo -e "  \033[1m-i --instruct\033[0m <string>     set system instructions (see note below)"
  echo -e "  \033[1m-t --maxtokens\033[0m <integer>   set the max tokens for the response (default: \033[1m1024\033[0m)"
  echo ""
  echo -e "\033[1;32mModels:\033[0m"
  echo -e "  \033[1mmini\033[0m    OpenAI ChatGPT 4.1 mini"
  echo -e "  \033[1mnano\033[0m    OpenAI ChatGPT 4.1 nano"
  echo -e "  \033[1mhaiku\033[0m   Anthropic Claude 4.5 haiku"
  echo -e "  \033[1mmistral\033[0m Mistral Small"
  echo ""
  echo -e "\033[1;32mNote:\033[0m"
  echo -e "The default system instruction is: **\"This is a one-shot prompt, so don't ask the user any follow-up questions. Simply provide a response to the user's question. Further instructions: You are a helpful assistant.\"**\n\nYour custom instructions will replace the \"You are a helpful assistant\" part." | glow -
}

# Set defaults
MODEL_CODE="gpt-4.1-nano"
MODEL_ALIAS="nano"
PROVIDER="openai"
SYSTEM_INSTRUCTION="This is a one-shot prompt, so don't ask the user any follow-up questions. Simply provide a response to the user's question. The user provided this further instruction:"
FURTHER_INSTRUCTION="You are a helpful assistant."
MAX_TOKENS=1024

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--model)
      MODEL_ALIAS="$2"
      case $2 in
        "mini")
          MODEL_CODE="gpt-4.1-mini"
          PROVIDER="openai"
        ;;
        "nano")
          MODEL_CODE="gpt-4.1-nano"
          PROVIDER="openai"
        ;;
        "haiku")
          MODEL_CODE="claude-haiku-4-5"
          PROVIDER="anthropic"
        ;;
        "mistral")
          MODEL_CODE="mistral-small"
          PROVIDER="mistral"
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
      FURTHER_INSTRUCTION="$2"
      shift 2
      ;;
    -t|--maxtokens)
      if [[ -z "$2" ]]; then
        echo "Missing max tokens integer argument."
        exit 1
      fi
      MAX_TOKENS=$2
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

echo -e -n "\033[1mConfig:\033[0m"
echo -e "\
| **Option** | **Value** |\n \
| - | - |\n \
| model | $MODEL_CODE |\n \
| max tokens | $MAX_TOKENS |\n \
| instruction | $FURTHER_INSTRUCTION | \
" | glow -
echo -e -n "\033[1mYour question:\033[0m "
read -r -p "" QUESTION

openai_request() {
  payload=$(jq -n \
    --arg model "$MODEL_CODE" \
    --arg input "'$QUESTION'" \
    --arg instructions "$SYSTEM_INSTRUCTION $FURTHER_INSTRUCTION" \
    --argjson max_output_tokens "$MAX_TOKENS" \
    '{model: $model, input: $input, instructions: $instructions, max_output_tokens: $max_output_tokens}'\
  )
  local response=$(curl --silent https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$payload"
  )
  echo "$response" | jq -r '.output[0].content[0].text'
}

anthropic_request() {
  payload=$(jq -n \
    --arg model_code "$MODEL_CODE" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg system "$SYSTEM_INSTRUCTIONS $FURTHER_INSTRUCTION" \
    --arg role "user" \
    --arg content "'$QUESTION'" \
    '{
      model: $model_code,
      max_tokens: $max_tokens,
      system: $system,
      messages: [
        {
          role: $role,
          content: $content
        }
      ]
    }'
  )
	local response=$(curl --silent https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$payload"
  )
	echo "$response" | jq -r '.content[0].text'
}

mistral_request() {
  payload=$(jq -n \
    --arg model "$MODEL_CODE" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg system "$SYSTEM_INSTRUCTION $FURTHER_INSTRUCTION" \
    --arg user_content "$QUESTION" \
    '{
      model: $model,
      max_tokens: $max_tokens,
      messages: [
        {
          role: "system",
          content: $system
        },
        {
          role: "user",
          content: $user_content
        }
      ]
    }'\
  )
  local response=$(curl --silent https://api.mistral.ai/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -d "$payload"
  )
  echo "$response" | jq -r '.choices[0].message.content'
}

RESPONSE=""
case $PROVIDER in
  "openai")
    RESPONSE=$(openai_request)
    ;;
  "anthropic")
    RESPONSE=$(anthropic_request)
    ;;
  "mistral")
    RESPONSE=$(mistral_request)
    ;;
  *)
    echo "Unknown provider: $PROVIDER"
    exit 1
    ;;
esac

echo -e "\n\033[1m$MODEL_ALIAS's response:\033[0m"
echo "$RESPONSE" | glow -

