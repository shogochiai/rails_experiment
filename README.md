#目的

[rails3とrails4の速度比較](http://qiita.com/sgtn/items/65815b0e0ae55482cede)のリベンジ。

今回の改善点として、rubyのバージョンを固定することによって

単純なrailsの速度差を測定することが可能な点がある。

また、rubyのバージョンとrailsのバージョンの相性

（つまり各バージョンのrubyのgem rails/railtiesの実装の差異）が浮き彫りになることを期待している。


---


#実験系

##概要
各バージョンの組み合わせで

`rails g scaffold blog title:string description:string`を行った後、

`rake routes`および`spring rake routes`にかかった秒数を10回測定し、その平均値を出力する。

実験系は半自動化されており、シェルスクリプト１つと、awkファイル１つがその全てである。

---

```zsh:experiment.sh

#!/bin/zsh

RUBY=("1.9.3-p484" "2.0.0-p353" "2.1.0-preview1") 
for ruby in ${RUBY[@]}; do
  export PATH=$RBENV_ROOT/shims:$PATH
  rbenv global $ruby >/dev/null 2>&1

  RAILS_VER=("3.2.15" "4.0.2") 
  for rails_ver in ${RAILS_VER[@]}; do
    gem install rails -v $rails_ver >/dev/null 2>&1
    if test $rails_ver = '3.2.15' ; then
      gem uninstall rails -v "4.0.2" >/dev/null 2>&1
      gem uninstall railties -v "4.0.2" >/dev/null 2>&1
    else
      gem uninstall rails -v "3.2.15" >/dev/null 2>&1
      gem uninstall railties -v "3.2.15" >/dev/null 2>&1
    fi
    rbenv rehash
    ruby -v
    rails -v
    rails new rails_${rails_ver}_speedtest -d mysql >/dev/null 2>&1
    echo "gem 'spring'" >> ./rails_${rails_ver}_speedtest/Gemfile
    cd ./rails_${rails_ver}_speedtest
    bundle install --path vendor/bundle >/dev/null 2>&1
    bundle exec spring rails g scaffold blog title:string description:string >/dev/null 2>&1

    echo not_spring
    for i in {1..10};do
      bundle exec time rake routes | grep real
    done 2> routes.txt
    awk -f ../ave.awk routes.txt
    echo spring
    for i in {1..10};do
      bundle exec time spring rake routes | grep real
    done 2> routes.txt
    awk -f ../ave.awk routes.txt
    cd ..
    rm -rf ./rails_${rails_ver}_speedtest
  done
done

```

```awk:ave.awk

{
  sum += $1
  ave = sum/10
}
END{
  print ave
}

```

##手順

`rbenv install 1.9.3-p484`

`rbenv install 2.0.0-p353`

`rbenv install 2.1.0-preview1`

はやっておくこと

また、既にこれらのバージョンを使用していてgem railsをインストールしてる場合は

`gem install rails -v 3.2.15`

`gem install rails -v 4.0.2`

`gem uninstall rails -v 4.0.2`

`gem uninstall rails -v [既存バージョン]`

`gem uninstall railties -v 4.0.2`

`gem uninstall railties -v [既存バージョン]`

という処理をして、railsのバージョンを3.2.15にしておくと

エラーに遭遇する可能性が減ることが確認されている（railsの競合を手動で解消）。

さて、このシェルスクリプトは稚拙なためにプロセス間通信などは避けて作られている。

よって`zsh experiment.sh`などで子プロセスで動かすことはできない。

したがって`source experiment.sh`を実行する必要がある。

このとき、ave.awkとexperiment.shは同じディレクトリに存在する必要がある。

`source experiment.sh`を実行した後は条件が整って入れば結果を待つのみである。

手動でデータを取っていてはミスが多い上に待ち時間がもったいなかったのでスクリプトにした。自動化万歳。

---

#結果

以下のような出力が得られた。

また、ruby1.9.3/rails3.2.15のデータを1として比をとったものも記す。

![Screenshot 2013-12-19 00.48.27.png](https://qiita-image-store.s3.amazonaws.com/0/26475/287508db-59fb-dad7-384f-2320a38ebf73.png)


#考察

一概にどのバージョンが優れているかを明言できるほどの性能差はないが、

速度的な面に限って言えばrailsとrubyのバージョンの相性というものが存在するようだ。

このデータは１０回平均を取った物であり、データのばらつきに特筆すべき点もなかったため、精度は妥当なものだと思われる。

また、springは初回のみ通常の早さで二回目から70%ほど処理を軽くしてくれるので、

spring有りのデータはその誤差を吸収するために100回平均くらいをとっておきたかったが、

時間の関係上簡単にさせていただいた。

---

#余談

rails2系のデータもとろうと考えたのですが、3系以降と実装がまったく違ったので自動化しきれませんでした・・・orz

あと、気になるデータとして

ruby1.9.3×rails4.0.2が1.5倍ほど時間がかかっている点、

ruby2.1.0×rails3.2.15が0.7倍ほどの時間で済んでいる点、

このあたりは少し気になったので調査を続けたいと思います。

---

#追記

速度比表のrails3系と4系を比較するとnot springでは軒並み遅くなっていることが確認できます。

しかし、spring有りの速度比表では3系と4系に差はない。

つまり

[springで爆速rake生活](http://qiita.com/sgtn/items/a0f1ac313f0fad959299)で触れたように、

**rails4からspringが高速化している**

という証拠になり得るのではないかと考えました。

ruby2.1.0ではspringによる速度向上があまり見られませんが、springが最適化されると更に早くなることもある…のでしょうか？(自信ない)

