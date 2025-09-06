set -e

readonly SCRIPTROOT=$( cd $( dirname $0 ); pwd )
readonly PROJROOT=$( cd $SCRIPTROOT/..; pwd )

cd $PROJROOT

docker run -ti --rm \
    -v "$PWD":/build \
    -w /build \
    erlang:28 \
    rebar3 test
