#!/bin/sh

set -e

test_description='git-shared-submodule-update tests'

t=$(dirname "$0")
PATH=$(cd "$t/.."; pwd):$PATH
export PATH

. "$t/sharness/sharness.sh"

export GIT_SHARED_SUBMODULE_ROOT="$SHARNESS_TRASH_DIRECTORY/.git-shared-submodule"
rm -rf   "$GIT_SHARED_SUBMODULE_ROOT"
mkdir -p "$GIT_SHARED_SUBMODULE_ROOT"

counter_file="$SHARNESS_TRASH_DIRECTORY/counter"
echo 1 > "$counter_file"

__git_commit () {
    counter=$(cat "$counter_file")
    echo file "$counter" >> "FILE_$counter"
    git add "FILE_$counter"
    git commit -q -m "commit #$counter at $(basename "$(pwd)")"
    echo $(( counter + 1 )) > "$counter_file"
}

git config --global user.name  'tester'
git config --global user.email 'test@example.com'

for repo in project-foo project-bar module-a module-b; do
    mkdir -p "orig/$repo"

    ( cd "orig/$repo"
      git init --bare
    ) >&3 2>&4

    ( git clone -q "orig/$repo" "tmp/$repo"
      cd "tmp/$repo"
      __git_commit
      git push -q origin master ) >&3 2>&4
done

path_module_a=$(cd "orig/module-a" && pwd)
path_module_b=$(cd "orig/module-b" && pwd)

( cd tmp/project-foo
  git submodule add "$path_module_a"
  git commit -m 'added module-a to foo'
  git push origin master ) >&3 2>&4

( cd tmp/project-bar
  git submodule add "$path_module_a"
  git commit -m 'added module-a to bar'
  git push -q origin master ) >&3 2>&4

( cd tmp/project-bar
  git submodule add "$path_module_b"
  git commit -m 'added module-b to foo'
  git push -q origin master ) >&3 2>&4

# done initializing

test_expect_success 'shared-submodule-update --init <path> succeeds' '
  ( git clone -q --no-local orig/project-foo repo/project-foo &&
    cd repo/project-foo &&
    git submodule status module-a | grep "^-" &&
    git shared-submodule-update --init --no-dissociate module-a &&
    git submodule status module-a | grep "^ " &&
    test -f .git/modules/module-a/objects/info/alternates
    )
'

test_expect_success 'shared-submodule-update --init succeeds on another repo' '
  ( git clone -q --no-local orig/project-bar repo/project-bar &&
    cd repo/project-bar &&
    git submodule status module-a | grep "^-" &&
    git submodule status module-b | grep "^-"
    git shared-submodule-update --init &&
    git submodule status module-a | grep "^ " &&
    git submodule status module-b | grep "^ " &&
    ! test -f .git/modules/module-a/objects/info/alternates
    )
'

test_done
