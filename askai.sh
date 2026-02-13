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
  echo -e "  \033[1m-f --file\033[0m <path>           attach file contents to the prompt (can be used multiple times)"
  echo -e "  \033[1m-o --output\033[0m <path>         save response to file instead of displaying"
  echo ""
  echo -e "\033[1;32mModels:\033[0m"
  echo -e "  \033[1mmini\033[0m    OpenAI ChatGPT 4.1 mini"
  echo -e "  \033[1mnano\033[0m    OpenAI ChatGPT 4.1 nano"
  echo -e "  \033[1mhaiku\033[0m   Anthropic Claude 4.5 haiku"
  echo -e "  \033[1msonnet\033[0m  Anthropic Claude 3.5 sonnet"
  echo -e "  \033[1mmistral\033[0m Mistral Small"
  echo ""
  echo -e "\033[1;32mNote:\033[0m"
  echo -e "The default system instruction is: **\"This is a one-shot prompt, so don't ask the user any follow-up questions. Simply provide a response to the user's question. Further instructions: You are a helpful assistant.\"**\n\nYour custom instructions will replace the \"You are a helpful assistant\" part." | glow -
  echo ""
  echo -e "\033[1;32mFile Input Examples:\033[0m"
  echo -e "  $0 -f script.py \"What does this script do?\""
  echo -e "  $0 -f main.py -f utils.py \"Find bugs in these files\""
  echo -e "  $0 -m haiku -f config.json \"Explain this configuration\""
  echo ""
  echo -e "\033[1;32mFile Output Examples:\033[0m"
  echo -e "  $0 -o response.txt \"Explain quantum computing\""
  echo -e "  $0 -f code.py -o analysis.md \"Review this code\""
}

# Set defaults
MODEL_CODE="gpt-4.1-nano"
MODEL_ALIAS="nano"
PROVIDER="openai"
SYSTEM_INSTRUCTION="This is a one-shot prompt, so don't ask the user any follow-up questions. Simply provide a response to the user's question. The user provided this further instruction:"
FURTHER_INSTRUCTION="You are a helpful assistant."
MAX_TOKENS=1024
FILE_PATHS=()
VALID_FILE_PATHS=()  # Track files that pass validation
OUTPUT_FILE=""

# File size limits (in bytes)
MAX_FILE_SIZE=$((100 * 1024))      # 100KB per file
MAX_TOTAL_SIZE=$((500 * 1024))     # 500KB total

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
        "sonnet")
          MODEL_CODE="claude-sonnet-4-5"
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
    -f|--file)
      if [[ -z "$2" ]]; then
        echo "Missing file path argument."
        exit 1
      fi
      FILE_PATHS+=("$2")
      shift 2
      ;;
    -o|--output)
      if [[ -z "$2" ]]; then
        echo "Missing output file path argument."
        exit 1
      fi
      OUTPUT_FILE="$2"
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

# Validate output file path if provided
validate_output_path() {
  local output_path="$1"
  local output_dir=$(dirname "$output_path")

  # Check if directory exists
  if [[ ! -d "$output_dir" ]]; then
    echo "Error: Output directory does not exist: $output_dir"
    exit 1
  fi

  # Check if directory is writable
  if [[ ! -w "$output_dir" ]]; then
    echo "Error: Output directory is not writable: $output_dir"
    exit 1
  fi

  # Check if file exists and warn user
  if [[ -f "$output_path" ]]; then
    echo "Warning: Output file already exists and will be overwritten: $output_path"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      exit 0
    fi
  fi
}

# Validate and read files
validate_and_read_files() {
  local total_size=0
  VALID_FILE_PATHS=()  # Reset the valid files array
  
  for file_path in "${FILE_PATHS[@]}"; do
    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
      echo "Error: File not found: $file_path"
      exit 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$file_path" ]]; then
      echo "Error: File not readable: $file_path"
      exit 1
    fi
    
    # Get file size
    local file_size=$(wc -c < "$file_path")
    
    # Check individual file size limit
    if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
      echo "Error: File too large: $file_path ($(numfmt --to=iec-i --suffix=B $file_size), max $(numfmt --to=iec-i --suffix=B $MAX_FILE_SIZE))"
      exit 1
    fi
    
    # Check if file is likely binary (but allow common text extensions)
    local extension="${file_path##*.}"
    local is_text_extension=false
    
    # Common text file extensions
    case "$extension" in
      txt|md|py|js|ts|jsx|tsx|java|c|cpp|h|hpp|cs|rb|go|rs|php|html|css|scss|sass|json|xml|yaml|yml|sh|bash|zsh|sql|r|R|swift|kt|m|scala|pl|lua|vim|el|clj|ex|exs|erl|hrl|hs|ml|pas|ada|f90|f95|asm|s|d|nim|v|sv|vhd|vhdl|tcl|awk|sed|dockerfile|makefile|cmake|gradle|maven|ini|cfg|conf|config|toml|env|gitignore|log)
        is_text_extension=true
        ;;
    esac
    
    # If not a known text extension, check with file command
    if [[ "$is_text_extension" == false ]]; then
      if file "$file_path" | grep -qE 'executable|compressed|archive|image|video|audio|font'; then
        echo "Warning: Skipping likely binary file: $file_path"
        continue  # Skip to next file - don't add to VALID_FILE_PATHS
      fi
    fi
    
    # File passed all checks - add to valid list
    VALID_FILE_PATHS+=("$file_path")
    total_size=$((total_size + file_size))
  done
  
  # Check total size limit
  if [[ $total_size -gt $MAX_TOTAL_SIZE ]]; then
    echo "Error: Total file size too large ($(numfmt --to=iec-i --suffix=B $total_size), max $(numfmt --to=iec-i --suffix=B $MAX_TOTAL_SIZE))"
    exit 1
  fi
  
  if [[ ${#VALID_FILE_PATHS[@]} -eq 0 ]]; then
    echo "Warning: No valid files to include after validation"
  else
    echo "Files validated successfully: ${#VALID_FILE_PATHS[@]} file(s), total size: $(numfmt --to=iec-i --suffix=B $total_size)"
  fi
}

# Format files for OpenAI/Mistral (Option A: Simple concatenation)
format_files_simple() {
  local formatted=""
  
  for file_path in "${VALID_FILE_PATHS[@]}"; do
    # Skip if file doesn't exist or isn't readable (shouldn't happen after validation)
    if [[ ! -r "$file_path" ]]; then
      continue
    fi
    
    local file_content=$(cat "$file_path" 2>/dev/null)
    
    # Check if we actually got content
    if [[ -z "$file_content" ]]; then
      echo "Warning: Could not read content from: $file_path" >&2
      continue
    fi
    
    formatted+="File: $file_path"$'\n'
    formatted+="---"$'\n'
    formatted+="$file_content"$'\n'
    formatted+="---"$'\n\n'
  done
  
  echo "$formatted"
}

# Format files for Anthropic Claude (Option B: XML tags)
format_files_xml() {
  local formatted="<files>"$'\n'
  
  for file_path in "${VALID_FILE_PATHS[@]}"; do
    # Skip if file doesn't exist or isn't readable (shouldn't happen after validation)
    if [[ ! -r "$file_path" ]]; then
      continue
    fi
    
    local file_content=$(cat "$file_path" 2>/dev/null)
    
    # Check if we actually got content
    if [[ -z "$file_content" ]]; then
      echo "Warning: Could not read content from: $file_path" >&2
      continue
    fi
    
    formatted+="<file path=\"$file_path\">"$'\n'
    formatted+="$file_content"$'\n'
    formatted+="</file>"$'\n'
  done
  
  formatted+="</files>"$'\n\n'
  echo "$formatted"
}

# Build file content display for config
build_files_display() {
  if [[ ${#FILE_PATHS[@]} -eq 0 ]]; then
    echo "none"
  else
    echo "${#FILE_PATHS[@]} file(s): ${FILE_PATHS[*]}"
  fi
}

# Validate files if any were provided
if [[ ${#FILE_PATHS[@]} -gt 0 ]]; then
  validate_and_read_files
fi

# Validate output path if provided
if [[ -n "$OUTPUT_FILE" ]]; then
  validate_output_path "$OUTPUT_FILE"
fi

echo -e -n "\033[1mConfig:\033[0m"
echo -e "\
| **Option** | **Value** |\n \
| - | - |\n \
| model | $MODEL_CODE |\n \
| max tokens | $MAX_TOKENS |\n \
| instruction | $FURTHER_INSTRUCTION |\n \
| files | $(build_files_display) |\n \
| output | ${OUTPUT_FILE:-stdout} | \
" | glow -
echo -e -n "\033[1mYour question:\033[0m "
read -r -p "" QUESTION

# Debug: Show if files will be included
if [[ ${#VALID_FILE_PATHS[@]} -gt 0 ]]; then
  echo -e "\033[2m[Debug: Including ${#VALID_FILE_PATHS[@]} file(s) in prompt]\033[0m"
fi

openai_request() {
  local full_input="$QUESTION"
  
  # Prepend file contents if any files were provided
  if [[ ${#VALID_FILE_PATHS[@]} -gt 0 ]]; then
    local files_content=$(format_files_simple)
    full_input="${files_content}User question: $QUESTION"
  fi
  
  payload=$(jq -n \
    --arg model "$MODEL_CODE" \
    --arg input "$full_input" \
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
  local full_content="$QUESTION"
  
  # Prepend file contents if any files were provided
  if [[ ${#VALID_FILE_PATHS[@]} -gt 0 ]]; then
    local files_content=$(format_files_xml)
    full_content="${files_content}<question>$QUESTION</question>"
  fi
  
  payload=$(jq -n \
    --arg model_code "$MODEL_CODE" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg system "$SYSTEM_INSTRUCTION $FURTHER_INSTRUCTION" \
    --arg role "user" \
    --arg content "$full_content" \
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
  local user_content="$QUESTION"
  
  # Prepend file contents if any files were provided
  if [[ ${#VALID_FILE_PATHS[@]} -gt 0 ]]; then
    local files_content=$(format_files_simple)
    user_content="${files_content}User question: $QUESTION"
  fi
  
  payload=$(jq -n \
    --arg model "$MODEL_CODE" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg system "$SYSTEM_INSTRUCTION $FURTHER_INSTRUCTION" \
    --arg user_content "$user_content" \
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

# Output response to file or stdout
if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$RESPONSE" > "$OUTPUT_FILE"
  echo -e "\n\033[1;32m✓ Response saved to:\033[0m $OUTPUT_FILE"
  echo ""
  echo -e "\033[2mPreview:\033[0m"
  head -n 5 "$OUTPUT_FILE" | glow -
  if [[ $(wc -l < "$OUTPUT_FILE") -gt 5 ]]; then
    echo -e "\033[2m... (file continues)\033[0m"
  fi
else
  echo -e "\n\033[1m$MODEL_ALIAS's response:\033[0m"
  echo "$RESPONSE" | glow -
fi
