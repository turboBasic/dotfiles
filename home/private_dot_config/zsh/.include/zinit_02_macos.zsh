### macOS template begin

zinit for \
    --lucid \
    --wait \
    --id-as='iterm2-color-schemes' \
    --as='null' \
    --depth='1' \
    --atclone='cp -fv tools/preview.rb ~/.local/bin/preview.rb' \
    --run-atpull \
    --atpull='%atclone' \
    mbadolato/iTerm2-Color-Schemes

### macOS template end
