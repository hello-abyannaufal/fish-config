if status is-interactive
    # Commands to run in interactive sessions can go here
end

source ~/.config/fish/functions/common.fish

string match -q "$TERM_PROGRAM" "kiro" and . (kiro --locate-shell-integration-path fish)
