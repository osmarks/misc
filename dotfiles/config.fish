if status is-interactive
    zoxide init fish | source
    atuin init fish | source
end
if status is-login
  and status is-interactive
    # disabled for performance reasons
    #keychain --eval $SSH_KEYS_TO_AUTOLOAD 2> /dev/null | source
end

functions -q real_cd; or functions -c cd real_cd
function cd
    set -g PREV_PWD
    real_cd $argv
end

function __project_jail_chpwd --on-variable PWD
    if set -q NORECURSE
        set -e NORECURSE
        return
    end
    if set -q DISABLE_SANDBOX_ONCE
        set -e DISABLE_SANDBOX_ONCE
        return
    end
    if set -q IN_PROJECT_JAIL
        return
    end

    if test -x ~/.local/bin/project-jail
        set -l back "$PREV_PWD"
        test -n "$back"; or set back "$HOME"
        if ~/.local/bin/project-jail
            set -g NORECURSE
            cd "$back"
        end
    end
end

function disable_sandbox
    set -g DISABLE_SANDBOX_ONCE
end

# Also check once at shell startup.
if not set -q IN_PROJECT_JAIL
    if test -x ~/.local/bin/project-jail
        ~/.local/bin/project-jail
    end
end

# why did they do this? why do they hate me so?
bind ctrl-left backward-word
bind ctrl-right forward-word
bind alt-left prevd-or-backward-token
bind alt-right nextd-or-forward-token
