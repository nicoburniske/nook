fzf-file-picker() {
  local token="${LBUFFER##* }"
  local directory="$token"
  local selected

  if [[ $directory == "~" || $directory == "~/"* ]]; then
    directory="$HOME${directory#\~}"
  fi

  if [[ ! -d $directory ]]; then
    directory="${directory:h}"
  fi

  [[ -d $directory ]] || directory=$PWD

  selected=$(fzf --walker=file,dir,follow,hidden --scheme=path --walker-root="$directory" < /dev/tty) || {
    zle reset-prompt
    return
  }

  LBUFFER="${LBUFFER[1,$(( ${#LBUFFER} - ${#token} ))]}${(q)selected} "
  zle reset-prompt
}

zle -N fzf-file-picker
bindkey '^T' fzf-file-picker
