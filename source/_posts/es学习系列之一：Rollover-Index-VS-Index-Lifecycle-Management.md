---
title: es学习系列之一：Rollover Index VS. Index Lifecycle Management
date: 2020-05-17 16:40:19
tags:
    - elasticsearch
---

> 如无特别说明，本文讨论的内容均基于 es 7.*

## es的Rollover索引

es的Rollover索引通常指的是一个别名指向某个索引，并且能够在索引的某些条件下进行轮转，如索引的创建时间长短、大小、文档数量。

如创建一个名为 nginx_log-000001 的索引，并指定其alias为nginx_log_write，并且我们对nginx_log_write写入3个文档（其实也是对nginx_log-000001写）。然后对别名调用rollover接口，
由于已经达到文档数目为3的条件，则会自动生成 nginx_log-000002 的索引。这时对nginx_log_write写入会自动写入到nginx_log-000002索引中。

需要注意的是，由于对索引设置alias的时候，没有添加 `"is_write_index": true` 配置，则在执行rollover并创建新索引成功后，将会只指向**一个**索引（新索引），对nginx_log_write查询只能查到最新索引的数据，而不能查到历史数据。相反，如果配置了`"is_write_index": true`，在rollover后alias会**同时**指向多个索引，并且最新索引设置为`"is_write_index": true`，旧索引设置为`"is_write_index": false`，对alias的
写入就是对最新索引的写入，查询时是对所有索引进行**查询**。

```
# 创建索引nginx_log-000001，并设置其别名为nginx_log_write
PUT /nginx_log-000001
{
  "aliases": {
    "nginx_log_write": {
    }
  }
}

# 对别名写入文档，重复执行3次
POST nginx_log_write/_doc
{
  "log":"something before rollover"
}

# 对别名执行rollover
POST /nginx_log_write/_rollover
{
  "conditions": {
    "max_age":   "1d",
    "max_docs":  3,
    "max_size":  "5gb"
  }
}

# 对新索引插入新数据
POST nginx_log_write/_doc
{
  "log":"something after rollover"
}

# 分别查 nginx_log-000001、nginx_log-000002、nginx_log_write，对ginx_log_write只能查到最新索引的数据
POST nginx_log_write/_search
{
  "query":{
    "match_all": {
    }
  }
}

# 对非 "is_write_index": true 模式的索引，可用 index_name-* 查询所有数据
POST nginx_log-*/_search
{
  "query":{
    "match_all": {
    }
  }
}
```

另外，我们可以利用 [Date Math](https://www.elastic.co/guide/en/elasticsearch/reference/7.2/date-math-index-names.html) 创建带日期的rollover索引，更加方便索引管理。

```
# PUT /<nginx_log-{now/d}-000001>，将创建名为 nginx_log-2020.05.17-000001 的索引
PUT /%3Cnginx_log-%7Bnow%2Fd%7D-000001%3E
{
  "aliases": {
    "nginx_log_write": {
    }
  }
}

```

需要注意的是 `_rollover` api只会对调用该接口的那个时刻有效，当然可以自己独立做一个任务周期性扫描所有别名，当别名到达一定条件后就调用其 `_rollover` 接口。如果需要es自身定时调用的话，可以使用自动化程度更高的 Index Lifecycle Management。

## Index Lifecycle Management

与 _rollover 索引相比，索引生命周期管理会更加自动化，ILM把索引的生命周期分为4个phase，分别为Hot、Warm、Cold、Delete。每个phase可以包含多个action。

| action | 允许该action的phase | action意义 |
| ---- | ---- | ---- |
| Rollover | hot | 和 rollover 索引的条件一致 |
| Read-Only | warm | 通过`"index.blocks.write": false` 把原索引会被设置只读 |
| Allocation | warm, cold | 移动索引时指定的亲和性规则，包括include, exclude, require。同时还可以通过 number_of_replicas 变更副本数量，比如指定为0。 |
| Shrink | warm | 合并shard，创建 shrink-${origin_index_name}，前提是需要把原索引的shard移动到同一个node上，需要留意node是否有足够的容量。并且会通过`"index.blocks.write": false` 把原索引会被设置只读，并最终删除原索引。 | 
| Force Merge | warm | 合并segmemt。和shrink一样，会通过`"index.blocks.write": false` 把原索引会被设置只读 |
| Freeze | cold | 冻结索引。适用于很少查询的旧索引，es通过冻结索引能够减少堆内存的使用 |
| Delete | delete | 删除索引 |
| Set Priority | hot, warm, cold | 重启时，恢复索引的优先度，值越大越优先恢复 | 
| Unfollow | hot,warm,cold | 应该是中间状态 |

<!--more-->

创建一个名为 my_policy 的索引周期管理策略，设置以下几个方面
- 如果索引文档超过10个则进行rollover，创建新索引。
- 原索引立刻移动到boxtype=warm的机器，然后创建名为 shrink_${index_name}的索引，同时把shard合并为1个（所有shard都会移动到同一个node），并创建原索引同名alias以及删除原索引，。
- 原索引被rollover 1h后，移动到boxtype=cold的机器。
- 原索引被rollover 2h后，直接被删除。

```
# 创建mypolicy
PUT /_ilm/policy/my_policy
{
    "policy": {
        "phases": {
            "hot": {
                "actions": {
                    "rollover": {
                        "max_docs": 10
                    },
                    "set_priority": {
                        "priority": 100
                    }
                }
            },
            "warm": {
                "actions": {
                    "allocate": {
                        "require": {
                            "box_type": "warm"
                        }
                    },
                    "shrink": {
                        "number_of_shards": 1
                    },
                    "set_priority": {
                        "priority": 50
                    }
                }
            },
            "cold": {
                "min_age": "1h",
                "actions": {
                    "allocate": {
                        "require": {
                            "box_type": "cold"
                        }
                    },
                    "set_priority": {
                        "priority": 0
                    }
                }
            },
            "delete": {
                "min_age": "2h",
                "actions": {
                    "delete": {}
                }
            }
        }
    }
}

# 设置索引模版
PUT /_template/log_ilm_template
{
  "index_patterns" : [
      "nginx_log-*"
    ],
    "settings" : {
      "index" : {
        "lifecycle" : {
          "name" : "my_policy",
          "rollover_alias" : "nginx_log_write"
        },
        "routing" : {
          "allocation" : {
            "require" : {
              "box_type" : "hot"
            }
          }
        },
        "number_of_shards" : "2",
        "number_of_replicas" : "0"
      }
    },
    "mappings" : { },
    "aliases" : { }
}


# 创建带时间的索引，并指定其别名为 nginx_log_write，并指定其只能分配在botx_type为hot的节点
# PUT /<nginx_log-{now/d}-000001>，将创建名为 nginx_log-2020.05.17-000001 的索引
PUT /%3Cnginx_log-%7Bnow%2Fd%7D-000001%3E
{
  "settings": {
    "index.routing.allocation.include.box_type":"hot"
  },
  "aliases": {
    "nginx_log_write": {
      "is_write_index": true
    }
  }
}

# 写入11个doc，最多等待10分钟机会索引就会被rollover
# 1.等待10分钟后可以发现 nginx_log-2020.05.17-000002 的索引被创建
# 2.创建了索引shrink-nginx_log-2020.05.21-000001，shard被shrink为1个，并删除原来的索引 nginx_log-2020.05.17-000001 
# 3.创建别名nginx_log-2020.05.21-000001指向索引shrink-nginx_log-2020.05.21-000001
POST nginx_log_write/_doc
{
  "log":"something 01"
}

# 如果觉得太久，可以ilm设置60秒刷新1次，默认为10分钟刷新一次
PUT _cluster/settings
{
  "persistent": {
    "indices.lifecycle.poll_interval":"60s"
  }
}

```

使用 IDM 的注意点：

- 创建索引时，设置alias需要指定`"is_write_index": true`
- 在设置index template时，在特settings中的 `"index.lifecycle.rollover_alias"` 设置的别名要和创建索引时指定的别名一致。
- index template中的 routing.allocation.${condiction} 最好和 IDM 中allocate指定的一致（即同时使用require，或者同时使用include）。因为这样才不会导致旧索引无法被已到新节点。比如index template指定 **include** hot，IDM warm中allocate中指定 **require** warm，那么在hot阶段rollover后进入到warm阶段的allocate，可能会导致将会无法移动索引，因为无法找到一个节点同时满足hot和warm节点。但是如果同时为include或者require，则IDM时会覆盖template设置的条件，索引可以成功移动。

### Rollover Index VS. Index Lifecycle Management

|  | 自动调用 | alias必须设置为write模式 | alias名称限定 | 支持时间序列索引 | 支持移动索引 |
| :----: | :----: | :----: | :----: | :----: | :----: |
| Rollover Index | 否 | 可选 | 否 | 是 | 否 |
| Index Lifecycle Management | 是，间隔为 indices.lifecycle.poll_interval | 是 | 需要和"index.lifecycle.rollover_alias"同名 | 是 | 是，需要注意index template中和IDM中使用同等类型的限制 | 


参考：  
[Rollover index API](https://www.elastic.co/guide/en/elasticsearch/reference/7.6/indices-rollover-index.html)   
[Actions](https://www.elastic.co/guide/en/elasticsearch/reference/7.6/_actions.html)  
[Index lifecycle actions](https://www.elastic.co/guide/en/elasticsearch/reference/7.6/ilm-actions.html)  


> 本文为学习过程中产生的总结，由于学艺不精可能有些观点或者描述有误，还望各位同学帮忙指正，共同进步。
