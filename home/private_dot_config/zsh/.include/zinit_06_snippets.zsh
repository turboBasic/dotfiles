### Zinit snippets script begin

zinit --lucid --wait for \
    --id-as='tb::aws-helpers' \
    https://gist.githubusercontent.com/turboBasic/02cf7612109d6d1434364bb7bf2d3ac6/raw/aws.zsh \
    --id-as='tb::git-commit-size' \
    https://gist.githubusercontent.com/turboBasic/7b5ac4b1524f19b4520ff61a4a9e78ed/raw/git-commit-size \
    --id-as='tb::locale-demo' \
    https://gist.githubusercontent.com/turboBasic/00d416619ed3fd8f20161c3449574c69/raw/locale-demo.zsh \
    --id-as='tb::ls-colors' \
    --nocompile='!' \
    --atclone='zsh --no-rcs tb::ls-colors molokai > colors.sh' \
    --pick='colors.sh' \
    --atpull='%atclone' \
    --atload='zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"' \
    https://gist.githubusercontent.com/turboBasic/26d0b94957864767a07f18e7c689a0ce/raw/generate.sh \
    --id-as='sqids' \
    --as='null' \
    --sbin='sqids' \
    --atclone='chmod +x sqids' \
    --atpull='%atclone' \
    https://raw.githubusercontent.com/sqids/sqids-bash/refs/heads/main/src/sqids \
    OMZL::clipboard.zsh \
    --atload='unfunction uninstall_oh_my_zsh upgrade_oh_my_zsh' \
    OMZL::functions.zsh \
    OMZL::git.zsh \
    --atload='fpath=( ${fpath:#${ZINIT[SNIPPETS_DIR]}/OMZP::z} )' \
    OMZP::z \
    OMZP::zsh-interactive-cd \
    \
    # last line ;)

### Zinit snippets script end
