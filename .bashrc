alias ll='ls -la --color'
alias ls='ls --color'
alias grep='grep --color'
alias c='xclip -selection clipboard'

export PATH="$PATH:$HOME/.local/bin/"
export PATH="$PATH:/home/horki/.nimble/bin"
export PATH="$PATH:/home/horki/repos/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi/bin"

. "$HOME/.local/bin/env"

eval "$(oh-my-posh init bash --config ~/.config/omp/half-life.json)"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
