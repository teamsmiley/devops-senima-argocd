# issue

경우에 따라 사용을 안하는것도 좋겟다.

aws / idc에서 동시에 아이피를 업데이트하면 에러가 된다.

인그레스 별로 사용을 막으려고 해봣는데 잘 안된다.

external-dns.alpha.kubernetes.io/exclude: 'true'

이걸로 검색하면 나오는데 동작이 안된다.

아이피를 두개를 넣는것도 잘 안된다. 클라우드 플레어는 2개의 raw를 넣어 라운드로빈을 함.

특정 아이피를 넣을려고 하면 인그레스에 다음을 사용한다.

```txt
external-dns.alpha.kubernetes.io/target: "204.16.116.100"
```
