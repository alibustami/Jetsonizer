#!/bin/bash

BASE_DIR="$(dirname "$(realpath "$0")")"
MODULES_DIR="$BASE_DIR/modules"
TESTS_DIR="$BASE_DIR/tests"
RESOURCES_DIR="$BASE_DIR/resources"
UTILS_DIR="$BASE_DIR/utils"
WHICH_PYTHON_SCRIPT="$UTILS_DIR/which_python.sh"

CATEGORY_NAMES=(
    "ML & Vision stack"
    "Python env & tooling"
    "IDEs"
    "Monitoring"
    "Browsers"
    "Validation"
    "Useful resources"
)
CATEGORY_ITEM_VARS=(
    "CATEGORY_ITEMS_ML_VISION"
    "CATEGORY_ITEMS_PY_ENV"
    "CATEGORY_ITEMS_IDE"
    "CATEGORY_ITEMS_MONITORING"
    "CATEGORY_ITEMS_BROWSER"
    "CATEGORY_ITEMS_VALIDATION"
    "CATEGORY_ITEMS_RESOURCES"
)
CATEGORY_SELECTABLE=(1 1 1 1 1 1 0)
CATEGORY_ITEMS_ML_VISION=("OpenCV with CUDA enabled" "PyTorch with CUDA acceleration" "TensorRT")
CATEGORY_ITEMS_PY_ENV=("MiniConda" "uv")
CATEGORY_ITEMS_IDE=("VS Code")
CATEGORY_ITEMS_MONITORING=("jtop")
CATEGORY_ITEMS_BROWSER=("Brave Browser")
CATEGORY_ITEMS_VALIDATION=("Run OpenCV CUDA test" "Run PyTorch CUDA test" "Run TensorRT test")
CATEGORY_ITEMS_RESOURCES=()

GREEN_TEXT="$(tput setaf 82 2>/dev/null || true)"
RESET_TEXT="$(tput sgr0 2>/dev/null || true)"

USEFUL_LINKS_FILE="$RESOURCES_DIR/useful_links.txt"
if [ -f "$USEFUL_LINKS_FILE" ]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        CATEGORY_ITEMS_RESOURCES+=("$line")
    done < "$USEFUL_LINKS_FILE"
fi

function show_help() {
    echo "Jetsonizer - The Ultimate NVIDIA Jetson Setup Tool"
    echo ""
    echo "Usage: jetsonizer [options]"
    echo ""
    echo "Description:"
    echo "  Jetsonizer automates the installation of complex components like OpenCV (CUDA),"
    echo "  PyTorch, TensorRT, and development tools on NVIDIA Jetson devices."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if ! command -v gum &> /dev/null; then
    echo "Gum not found. Installing dependencies (requires sudo)..."
    sudo bash "$UTILS_DIR/gum_installation.sh"
fi

gum style \
    --foreground 82 --border-foreground 82 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'JETSONIZER'

gum spin --spinner dot --title "Gathering system info..." --spinner.foreground="82" -- sleep 1

SYSTEM_ARCH=$(uname -m)
JETSONIZER_ACTIVE_PYTHON_BIN=""
JETSON_PYTHON_VERSION=""

if [ -x "$WHICH_PYTHON_SCRIPT" ]; then
    if JETSONIZER_ACTIVE_PYTHON_BIN="$(JETSONIZER_FORCE_REDETECT=1 "$WHICH_PYTHON_SCRIPT")"; then
        export JETSONIZER_ACTIVE_PYTHON_BIN
        if PYTHON_VERSION_OUTPUT=$("$JETSONIZER_ACTIVE_PYTHON_BIN" --version 2>&1 | head -n 1); then
            JETSON_PYTHON_VERSION=$(echo "$PYTHON_VERSION_OUTPUT" | awk '{print $2}')
        fi
    else
        gum style --foreground 196 --bold "❌ Unable to determine the active Python interpreter. Python-based installs will fail until this is resolved."
    fi
else
    gum style --foreground 214 --bold "⚠️  Python detector helper missing at $WHICH_PYTHON_SCRIPT."
fi

if [ -z "$JETSON_PYTHON_VERSION" ]; then
    if command -v python3 &> /dev/null; then
        JETSON_PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    else
        JETSON_PYTHON_VERSION="Not Found"
    fi
fi

RUN_PYTHON_BIN="$JETSONIZER_ACTIVE_PYTHON_BIN"
if [ -z "$RUN_PYTHON_BIN" ] && command -v python3 &> /dev/null; then
    RUN_PYTHON_BIN=$(command -v python3)
fi

gum style --foreground 82 --bold "Architecture: $SYSTEM_ARCH"
if [ -n "$JETSONIZER_ACTIVE_PYTHON_BIN" ]; then
    gum style --foreground 82 --bold "Python: $JETSON_PYTHON_VERSION ($JETSONIZER_ACTIVE_PYTHON_BIN)"
else
    gum style --foreground 214 --bold "Python: $JETSON_PYTHON_VERSION"
fi

function render_header_block() {
    gum style \
        --foreground 82 --border-foreground 82 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        'JETSONIZER'
    gum style --foreground 82 --bold "Architecture: $SYSTEM_ARCH"
    if [ -n "$JETSONIZER_ACTIVE_PYTHON_BIN" ]; then
        gum style --foreground 82 --bold "Python: $JETSON_PYTHON_VERSION ($JETSONIZER_ACTIVE_PYTHON_BIN)"
    else
        gum style --foreground 214 --bold "Python: $JETSON_PYTHON_VERSION"
    fi
}

function render_categories() {
    local current_index=$1
    printf "Categories: "
    for idx in "${!CATEGORY_NAMES[@]}"; do
        if [[ $idx -eq $current_index ]]; then
            printf "[%s%s%s] " "$GREEN_TEXT" "${CATEGORY_NAMES[$idx]}" "$RESET_TEXT"
        else
            printf " %s%s%s  " "$GREEN_TEXT" "${CATEGORY_NAMES[$idx]}" "$RESET_TEXT"
        fi
    done
    printf "\n\n"
}

function render_items() {
    local current_index=$1
    local current_item_index=$2
    local selectable="${CATEGORY_SELECTABLE[$current_index]}"
    local -n current_items="${CATEGORY_ITEM_VARS[$current_index]}"
    for idx in "${!current_items[@]}"; do
        local pointer=" "
        local marker="[ ]"
        if [[ $idx -eq $current_item_index ]]; then
            pointer=">"
        fi
        if [[ "$selectable" -eq 1 ]]; then
            if [[ -n "${SELECTIONS[${current_items[$idx]}]:-}" ]]; then
                marker="[x]"
            fi
            printf "%s %s %s%s%s\n" "$pointer" "$marker" "$GREEN_TEXT" "${current_items[$idx]}" "$RESET_TEXT"
        else
            printf "%s   %s%s%s\n" "$pointer" "$GREEN_TEXT" "${current_items[$idx]}" "$RESET_TEXT"
        fi
    done
}

function render_selection_summary() {
    if [[ ${#SELECTION_ORDER[@]} -eq 0 ]]; then
        gum style --foreground 244 "Selected: none"
        return
    fi

    gum style --foreground 82 --bold "Selected (${#SELECTION_ORDER[@]}):"
    for name in "${SELECTION_ORDER[@]}"; do
        gum style --foreground 82 "  - $name"
    done
}

function remove_from_selection_order() {
    local name=$1
    local updated=()
    for entry in "${SELECTION_ORDER[@]}"; do
        if [[ "$entry" != "$name" ]]; then
            updated+=("$entry")
        fi
    done
    SELECTION_ORDER=("${updated[@]}")
}

function run_selection_menu() {
    local current_category=0
    local -a category_cursors=()
    local total_categories=${#CATEGORY_NAMES[@]}
    for ((i=0; i<total_categories; i++)); do
        category_cursors[i]=0
    done

    clear
    render_header_block
    gum style --bold "Use Left/Right to change category, Up/Down to move, Space to toggle, Enter to install"
    printf "\n"
    tput sc

    while true; do
        tput rc
        tput ed
        render_categories "$current_category"

        local -n items="${CATEGORY_ITEM_VARS[$current_category]}"
        local selectable="${CATEGORY_SELECTABLE[$current_category]}"
        local item_count=${#items[@]}
        if [[ "$selectable" -ne 1 ]]; then
            gum style --foreground 244 "Viewing links (read-only)"
        fi
        if [[ $item_count -eq 0 ]]; then
            gum style --foreground 214 "No entries in this category."
        else
            local current_item_index=${category_cursors[$current_category]}
            if (( current_item_index >= item_count )); then
                current_item_index=0
                category_cursors[$current_category]=0
            fi
            render_items "$current_category" "$current_item_index"
        fi

        printf "\n"
        render_selection_summary

        IFS= read -rsn1 key
        if [[ -z "$key" ]]; then
            key=$'\x0a'
        fi
        if [[ $key == $'\x1b' ]]; then
            read -rsn1 -t 0.1 key2
            if [[ $key2 == "[" ]]; then
                read -rsn1 -t 0.1 key3
                case "$key3" in
                    "A")
                        if [[ ${#items[@]} -gt 0 ]]; then
                            local idx=${category_cursors[$current_category]}
                            idx=$(( (idx - 1 + item_count) % item_count ))
                            category_cursors[$current_category]=$idx
                        fi
                        ;;
                    "B")
                        if [[ ${#items[@]} -gt 0 ]]; then
                            local idx=${category_cursors[$current_category]}
                            idx=$(( (idx + 1) % item_count ))
                            category_cursors[$current_category]=$idx
                        fi
                        ;;
                    "C")
                        current_category=$(( (current_category + 1) % total_categories ))
                        ;;
                    "D")
                        current_category=$(( (current_category - 1 + total_categories) % total_categories ))
                        ;;
                esac
            fi
        elif [[ $key == " " ]]; then
            if [[ ${#items[@]} -gt 0 && "${selectable}" -eq 1 ]]; then
                local idx=${category_cursors[$current_category]}
                local item_name="${items[$idx]}"
                if [[ -n "${SELECTIONS[$item_name]:-}" ]]; then
                    unset "SELECTIONS[$item_name]"
                    remove_from_selection_order "$item_name"
                else
                    SELECTIONS["$item_name"]=1
                    SELECTION_ORDER+=("$item_name")
                fi
            fi
        elif [[ $key == $'\x0a' || $key == $'\r' ]]; then
            break
        fi
    done
}

declare -A SELECTIONS=()
SELECTION_ORDER=()
run_selection_menu

if [[ ${#SELECTION_ORDER[@]} -eq 0 ]]; then
    gum style --foreground 214 "No selections made. Exiting."
    exit 0
fi

gum style --foreground 82 --bold "Installing: ${SELECTION_ORDER[*]}"

for ITEM in "${SELECTION_ORDER[@]}"; do
    case "$ITEM" in
        "OpenCV with CUDA enabled")
            sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/router_opencv.sh"
            ;;
        "MiniConda")
            bash "$MODULES_DIR/install_miniconda.sh"
            ;;
        "PyTorch with CUDA acceleration")
            sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/router_torch.sh"
            ;;
        "VS Code")
            sudo bash "$MODULES_DIR/install_vscode.sh"
            ;;
        "uv")
            sudo bash "$MODULES_DIR/install_uv.sh"
            ;;
        "TensorRT")
            sudo env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" bash "$MODULES_DIR/link_tensorrt.sh"
            ;;
        "jtop")
            sudo bash "$MODULES_DIR/router_jtop.sh"
            ;;
        "Brave Browser")
            if [ -f "$MODULES_DIR/install_brave_browser.sh" ]; then
                sudo bash "$MODULES_DIR/install_brave_browser.sh"
            fi
            ;;
        "Run OpenCV CUDA test")
            bash "$TESTS_DIR/test_opencv_cuda.sh"
            ;;
        "Run PyTorch CUDA test")
            if [ -n "$RUN_PYTHON_BIN" ]; then
                env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" "$RUN_PYTHON_BIN" "$TESTS_DIR/test_torch_cuda.py"
            else
                gum style --foreground 214 "Skipping PyTorch CUDA test: no Python interpreter detected."
            fi
            ;;
        "Run TensorRT test")
            if [ -n "$RUN_PYTHON_BIN" ]; then
                env "JETSONIZER_ACTIVE_PYTHON_BIN=${JETSONIZER_ACTIVE_PYTHON_BIN:-}" "$RUN_PYTHON_BIN" "$TESTS_DIR/test_tensorrt.py"
            else
                gum style --foreground 214 "Skipping TensorRT test: no Python interpreter detected."
            fi
            ;;
    esac
done
