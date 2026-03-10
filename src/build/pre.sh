#!/bin/sh

wk="$1"
mm="$2"
yyyy="$3"

# stackoverflow.com/a/24753942
hasfwslash() {
    case "$1" in
    */*) echo yes ;;
    *       ) echo no ;;
    esac
}

burl="https://cfstore.rethinkdns.com/blocklists"
dir="bc"
codec="u6"
f="basicconfig.json"
f2="filetag.json"
cwd=$(pwd)
# exec this script from npm or project root
out="./src/${codec}-${f}"
out2="./src/${codec}-${f2}"
name=$(uname)

# timestamp: 1667519318.799 stackoverflow.com/a/69400542
# nowms =`date -u +"%s.%3N"`
if [ "$name" = "Darwin" ]
then
    now=$(date -u +"%s")
else
    now=$(date --utc +"%s")
fi


# date from timestamp: stackoverflow.com/a/16311821
if [ "$name" = "Darwin" ]
then
    day=$(date -r "$now" "+%d")
else
    day=$(date -d "@$now" "+%d")
fi
# ex: conv 08 => 8 stackoverflow.com/a/12821845
day=${day#0}
# week; ceil: stackoverflow.com/a/12536521
wkdef=$(((day + 7 -1) / 7))
# year
if [ "$name" = "Darwin" ]
then
    yyyydef=$(date -r "$now" "+%Y")
else
    yyyydef=$(date -d "@$now" "+%Y")
fi
# month
if [ "$name" = "Darwin" ]
then
    mmdef=$(date -r "$now" "+%m")
else
    mmdef=$(date -d "@$now" "+%m")
fi
mmdef=${mmdef#0}

# defaults: stackoverflow.com/a/28085062
: "${wk:=$wkdef}" "${mm:=$mmdef}" "${yyyy:=$yyyydef}"

# wget opts: superuser.com/a/689340
wgetopts="--tries=3 --retry-on-http-error=404 --waitretry=3 --no-dns-cache"

download() {
    url="$1"
    dest="$2"

    if command -v wget >/dev/null 2>&1; then
        wget $wgetopts -q "$url" -O "$dest"
        return $?
    fi

    if command -v deno >/dev/null 2>&1; then
        deno eval '
const [url, dest] = Deno.args;
const res = await fetch(url);
if (!res.ok) {
  console.error(`pre.sh: fetch failed ${res.status} ${url}`);
  Deno.exit(1);
}
await Deno.writeTextFile(dest, await res.text());
' "$url" "$dest"
        return $?
    fi

    echo "pre.sh: neither wget nor deno is available" >&2
    return 127
}

# stackoverflow.com/a/1445507
max=4
# 0..4 (5 loops)
for i in $(seq 0 $max)
do
    echo "x=== pre.sh: $i try $yyyy/$mm-$wk at $now from $cwd"

    # TODO: check if the timestamp within the json file is more recent
    # file/symlink exists? stackoverflow.com/a/44679975
    if [ -f "${out}" ] || [ -L "${out}" ]; then
        echo "=x== pre.sh: no op ${out}"
        exit 0
    else
        download "${burl}/${yyyy}/${dir}/${mm}-${wk}/${codec}/${f}" "${out}"
        wcode=$?

        if [ $wcode -eq 0 ]; then
            # baretimestamp=$(cut -d"," -f9 "$out" | cut -d":" -f2 | grep -o -E '[0-9]+' | tail -n1)
            fulltimestamp=$(cut -d"," -f9 "$out" | cut -d":" -f2 | tr -dc '0-9/')
            if [ "$(hasfwslash "$fulltimestamp")" = "no" ]; then
                echo "==x= pre.sh: $i filetag at f8"
                fulltimestamp=$(cut -d"," -f8 "$out" | cut -d":" -f2 | tr -dc '0-9/')
            fi
            echo "==x= pre.sh: $i ok $wcode; filetag? ${fulltimestamp}"
            download "${burl}/${fulltimestamp}/${codec}/${f2}" "${out2}"
            wcode2=$?
            if [ $wcode2 -eq 0 ]; then
              echo "===x pre.sh: $i filetag ok $wcode2"
              exit 0
            else
              rm -f "${out}" "${out2}"
              echo "===x pre.sh: $i not ok $wcode2"
              exit 1
            fi
        else
            # wget creates blank files on errs
            rm -f "${out}"
            echo "==x= pre.sh: $i not ok $wcode"
        fi
    fi

    # see if the prev wk was latest
    wk=$((wk - 1))
    if [ $wk -eq 0 ]; then
        # only feb has 28 days (28/7 => 4), edge-case overcome by retries
        wk="5"
        # prev month
        mm=$((mm - 1))
    fi
    if [ $mm -eq 0 ]; then
        mm="12"
        # prev year
        yyyy=$((yyyy - 1))
    fi
done

exit 1
