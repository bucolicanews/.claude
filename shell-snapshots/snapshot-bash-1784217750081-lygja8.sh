# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
shopt -s expand_aliases
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  function rg {
  local _cc_bin="${CLAUDE_CODE_EXECPATH:-}"
  [[ -x $_cc_bin ]] || _cc_bin=/c/Users/Micro/.local/bin/claude.exe
  if [[ ! -x $_cc_bin ]]; then command rg ${1+"$@"}; return; fi
  if [[ -n ${ZSH_VERSION:-} ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  else
    (exec -a rg "$_cc_bin" ${1+"$@"})
  fi
}
fi
export PATH='/c/Users/Micro/bin:/mingw64/bin:/usr/local/bin:/usr/bin:/bin:/mingw64/bin:/usr/bin:/c/Users/Micro/bin:/c/Users/Micro/AppData/Roaming/Code/User/globalStorage/github.copilot-chat/debugCommand:/c/Users/Micro/AppData/Roaming/Code/User/globalStorage/github.copilot-chat/copilotCli:/c/Windows/system32:/c/Windows:/c/Windows/System32/Wbem:/c/Windows/System32/WindowsPowerShell/v1.0:/c/Windows/System32/OpenSSH:/cmd:/c/Program Files/Docker/Docker/resources/bin:/c/Users/Micro/AppData/Local/hermes/hermes-agent/venv/Scripts:/c/Users/Micro/AppData/Local/hermes/bin:/c/Users/Micro/AppData/Local/Programs/Python/Python310/Scripts:/c/Users/Micro/AppData/Local/Programs/Python/Python310:/c/Users/Micro/AppData/Local/Programs/Python/Launcher:/c/Users/Micro/AppData/Local/Microsoft/WindowsApps:/c/Users/Micro/AppData/Local/Programs/Microsoft VS Code/bin:/c/Users/Micro/AppData/Local/Programs/Ollama:/c/Users/Micro/AppData/Local/hermes/node:/c/Users/Micro/AppData/Local/Microsoft/WinGet/Packages/BurntSushi.ripgrep.MSVC_Microsoft.Winget.Source_8wekyb3d8bbwe/ripgrep-15.1.0-x86_64-pc-windows-msvc:/c/Users/Micro/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.1-full_build/bin:/c/Users/Micro/.vscode/extensions/ms-python.debugpy-2026.6.0-win32-x64/bundled/scripts/noConfigScripts:/usr/bin/vendor_perl:/usr/bin/core_perl:/c/Users/Micro/.claude/plugins/cache/caveman/caveman/0d95a81d35a9/bin'
