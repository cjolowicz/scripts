#!/bin/bash

prog=$(basename $0)

### config #############################################################

product=helloworld
versionpath=VERSION
releasebranch=$product-release
maintenancebranch=$product-maintenance

### functions ##########################################################

usage () {
    echo "\
Usage: $prog --major   [options]
       $prog --minor   [options]
       $prog --patch   [options]
       $prog --rc      [options]
       $prog --release [options]

Options:

    -M, --major      Bump the major version.
    -m, --minor      Bump the minor version.
    -p, --patch      Bump the patch version.
    -R, --rc         Bump the rc number.
        --release    Add a release tag (no version bump).
        --force      Use a non-standard branch.
    -n, --dry-run    Just print what would be done.
    -h, --help       Display this message.

This script bumps the version number, and adds a version tag to the
repository.

For a major feature release, use \`$prog --major'.

For a normal feature release, use \`$prog --minor'.

For a maintenance release, use \`$prog --patch'.

If the current version failed QA, use \`$prog --rc' to prepare
another release candidate.

If the current version passed QA, use \`$prog --release' to add
a release tag. (This option does not bump the version number.)
"
    exit
}

error () {
    echo "$prog: error: $*" >&2
    exit 1
}

warn () {
    echo "$prog: warning: $*" >&2
}

softerror () {
    echo "$prog: error: $*" >&2
    echo "Use \`--force' to override." >&2
    exit 1
}

bad_usage () {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

### command line #######################################################

issue=
release=false
force=false
dry_run=false

while [ $# -gt 0 ] ; do
    option="$1"
    shift

    case $option in
        -M | --major)   issue=major ;;
        -m | --minor)   issue=minor ;;
        -p | --patch)   issue=patch ;;
        -R | --rc)      issue=rc ;;
             --release) release=true ;;
             --force)   force=true ;;
        -n | --dry-run) dry_run=true ;;
        -h | --help)    usage ;;
        --)             break ;;
        -*)             bad_usage "unrecognized option \`$option'" ;;
        *)              set -- "$option" "$@" ; break ;;
    esac
done

if $release && [ -n "$issue" ] ; then
    bad_usage "incompatible options \`--release' and \`--$issue'"
fi

if [ -z "$issue" ] && ! $release ; then
    usage
fi

if [ $# -gt 0 ] ; then
    bad_usage "unknown argument \`$1'"
fi

### main ###############################################################

root="$(hg root)" ||
    error "not in a mercurial repository"

branch="$(hg branch)" ||
    error "cannot determine current branch"

[ $(hg status -q | wc -l) -eq 0 ] ||
    error "working directory has uncommitted changes"

heads=($(hg heads --template '{node|short}\n' "$branch")) ||
    error "cannot determine branch heads"

[ ${#heads[@]} -eq 1 ] ||
    error "branch must have a single head"

parents=($(hg parents --template '{node|short}\n')) ||
    error "cannot determine parents of the working directory"

[ ${#parents[@]} -eq 1 ] ||
    error "working directory must have a single parent"

[ ${heads[0]} == ${parents[0]} ] ||
    error "working directory is not at the branch head"

versionfile="$root"/"$versionpath"

[ $(hg status -u "$versionfile" | wc -l) -eq 0 ] ||
    error "version file must be under revision control"

version="$(cat "$versionfile")" ||
    error "cannot read version file"

echo "$version" | grep -Eq '^ *[0-9]+(\.[0-9]+){3} *$' ||
    error "version file contains no well-formed version"

versiontag=$product-$version
releasetag=$versiontag-release

hg tags | grep -q "^${versiontag//./\\.}" ||
    error "no version tag for version $version"

versionbranch="$(hg log --template '{branch}' -r $versiontag)" ||
    error "cannot determine branch of $versiontag"

if $release ; then
    # Add a release tag to the repository.
    ! hg tags | grep -q "^${releasetag//./\\.}" ||
        error "$versiontag already has a release tag"

    [ "$branch" = "$versionbranch" ] ||
        error "$versiontag must be tagged on the $versionbranch branch \
(not $branch)"

    if ! $dry_run ; then
        hg tag -r $versiontag $releasetag ||
            error "cannot add release tag for $versiontag"
    fi

    echo "$versiontag => $releasetag"
else
    # Bump the version, and add a version tag to the repository.
    read major minor patch rc <<< ${version//./ }

    case $issue in
        major)
            pattern="^$product-$major(\\.[0-9]+){3}-release"
            hg tags | grep -Eq "$pattern" ||
                error "$versiontag has no major release tag"

            ((++major)) ; minor=0 patch=0 rc=0

            wantbranch=$releasebranch
            ;;

        minor)
            pattern="^$product-$major\\.$minor(\\.[0-9]+){2}-release"
            hg tags | grep -Eq "$pattern" ||
                error "$versiontag has no minor release tag"

            ((++minor)) ; patch=0 rc=0

            wantbranch=$releasebranch
            ;;

        patch)
            hg tags | grep -q "^${releasetag//./\\.}" ||
                error "$versiontag has no release tag"

            ((++patch)) ; rc=0

            wantbranch=$maintenancebranch
            ;;

        rc)
            ! hg tags | grep -q "^${releasetag//./\\.}" ||
                error "$versiontag has a release tag"

            ((++rc))

            wantbranch="$versionbranch"
            ;;
    esac

    newversion=$major.$minor.$patch.$rc
    newversiontag=$product-$newversion

    if [ "$branch" != "$wantbranch" ] ; then
        if $force ; then
            warn "force tagging of $newversiontag on the $branch branch \
(instead of $wantbranch)"
        else
            softerror "$newversiontag must be tagged on the $wantbranch \
branch (not $branch)"
        fi
    fi

    if ! $dry_run ; then
        echo $newversion > "$versionfile" ||
            error "cannot write version $newversion to version file"

        hg commit -m"Bump version to $newversion." ||
            error "cannot commit change of version file to version $newversion"

        hg tag $newversiontag ||
            error "cannot add version tag $newversiontag"
    fi

    echo "$versiontag => $newversiontag"
fi
