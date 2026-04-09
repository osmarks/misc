if status is-interactive
    zoxide init fish | source
    atuin init fish | source
end
if status is-login
  and status is-interactive
    # disabled for performance reasons
    #keychain --eval $SSH_KEYS_TO_AUTOLOAD 2> /dev/null | source
end

function __project_jail_chpwd --on-variable PWD
    if set -q NORECURSE
        set -e NORECURSE
        return
    end
    if set -q IN_PROJECT_JAIL
        return
    end

    if test -x ~/.local/bin/project-jail
        if ~/.local/bin/project-jail
            set -l back "$dirprev[1]"
            test -n "$back"; or set back "$HOME"
            set -g NORECURSE
            cd "$back"
        end
    end
end

# Also check once at shell startup.
if not set -q IN_PROJECT_JAIL
    if test -x ~/.local/bin/project-jail
        ~/.local/bin/project-jail
    end
end
