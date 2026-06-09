function pack
    set name $argv[1]
    tar -zcvf $name.tar.gz $name
end

# NVM Config
alias nrs18="nvm use 18; npm run serve"
alias nrs16="nvm use 16; npm run serve"
alias nrs14="nvm use 14; npm run serve"

# Apt Config
alias a-update="sudo apt update"
alias a-upgrade="sudo apt upgrade"

# Tar Config
alias comp="tar -zcvf"
alias extr="tar -zxvf"

# Explorer Config
alias nopen="xdg-open ."
alias eopen="explorer.exe ."

# Python Config
alias python=python3
alias pip=pip3

function dockerlaunch
    # Usage: dockerlaunch project-name image-name tag
    set project $argv[1]
    set image $argv[2]
    set tag $argv[3]

    docker build -t "$image:$tag" .
    docker tag "$image:$tag" nexus.pactindo.com:8443/$project/$image:$tag
    docker push nexus.pactindo.com:8443/$project/$image:$tag
end

function vpn
    if test (count $argv) -eq 0
        echo "Usage: vpn <profile> [--debug|-v]"
        echo "Available profiles:"
        ls ~/.config/openfortivpn
        return 1
    end

    set profile $argv[1]
    set debug 0

    if test (count $argv) -ge 2
        switch $argv[2]
            case "--debug" "-v"
                set debug 1
        end
    end

    set config ~/.config/openfortivpn/$profile/config

    if not test -f $config
        echo "Config not found: $config"
        return 1
    end

    if test $debug -eq 1
        echo "🔍 Debug mode enabled"
        sudo openfortivpn -vvv -c $config
    else
        sudo openfortivpn -c $config
    end
end
