if [ ! $1 ]; then
        echo "please specify repo name (osg-contrib, ost-release, etc.)"
                exit
fi

if [ ! $2 ]; then
        echo "please specify el name (el5, el6, etc..)"
        exit
fi

if [ ! $3 ]; then
        echo "please specify version (3.0)"
        exit
fi

release_path="/usr/local/repo/$3/$2/$1"
working_path="/usr/local/repo.working/$3/$2/$1"
previous_path="/usr/local/repo.previous/$3/$2/$1"
reponame=$3.$2.$1

mkdir -p $release_path $working_path $previous_path
mash $reponame -o $working_path -p $release_path
if [ "$?" -ne "0" ]; then
        echo "mash failed - please see error log" >&2
        exit 1
fi

rm -rf $previous_path
mv $release_path $previous_path 
mv $working_path/$reponame $release_path

if [ "$1" == "osg-release" ]; then
        echo "createing osg-release-latest symlink"
        cd /usr/local/repo
        target=$(find $3/$2/$1/x86_64 -name "osg-release*.rpm" | sort | tail -1)
        echo "target: $target"
        if [ $target ]; then
                ln -fs $target osg-$2-release-latest.rpm
        else
                echo "didn't find the osg-release.rpm under $3/$2/$1"
        fi
        cd -

fi

