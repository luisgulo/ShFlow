#!/bin/bash

Qes="8J+lmiBIYXMgZW5jb250cmFkbyBlbCBodWV2byBkZSBwYXNjdWEuIMKhQnVlbiBvam8h·4pyoIE5vIHRvZG9zIGxvcyBzY3JpcHRzIHRpZW5lbiBhbG1hLi4uIHBlcm8gZXN0ZSBzw60u·8J+noCBFbCBtZWpvciBidWcgZXMgZWwgcXVlIG51bmNhIGV4aXN0acOzLg==·8J+QoyBTaEZsb3cgdGUgc2FsdWRhIGRlc2RlIGxhcyBzb21icmFzLg==·8J+TnCBMYSBhdXRvbWF0aXphY2nDs24gdGFtYmnDqW4gdGllbmUgcG9lc8OtYS4="
Qen="8J+lmiBZb3UgZm91bmQgdGhlIEVhc3RlciBlZ2cuIFNoYXJwIGV5ZSE=·4pyoIE5vdCBhbGwgc2NyaXB0cyBoYXZlIHNvdWwuLi4gYnV0IHRoaXMgb25lIGRvZXMu·8J+noCBUaGUgYmVzdCBidWcgaXMgdGhlIG9uZSB0aGF0IG5ldmVyIGV4aXN0ZWQu·8J+QoyBTaEZsb3cgZ3JlZXRzIHlvdSBmcm9tIHRoZSBzaGFkb3dzLg==·8J+TnCBBdXRvbWF0aW9uIGhhcyBwb2V0cnkgdG9vLg=="
vhs=([0]="448b55f2" [1]="c9f66247" [2]="154f020f" [3]="0e931208" [4]="d2e2fa57")

sheg() {
    local P="$1" ; P=$((P+1))
    echo "――――――"
    echo "$Qes" |awk -F '·' -v p="$P"  '{print $p}' | base64 -d; echo
    echo "$Qen" |awk -F '·' -v p="$P"  '{print $p}' | base64 -d; echo
    echo "――――――"
}

main() {
    [[ $# -lt 1 ]] && return 0
    local input="$1" ; local hsh
    hsh=$(echo -n "$input" | md5sum | cut -c1-8)
    for n in "${!vhs[@]}"; do
        if [[ "$hsh" == "${vhs[$n]}" ]]; then
            sheg "$n" ; break
        fi
    done
    return 0
}

main "$@"
