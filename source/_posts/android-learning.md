---
title: android-learning
date: 2018-09-16 18:24:43
tags:
    - android
    - ip
---

# Show your ip by webrtc

代码: [链接](https://github.com/salmon7/ShowYourIP)

实际演示效果: [demo链接](https://salmon7.github.io/ShowYourIP/)

参考: https://github.com/diafygi/webrtc-ips

# Show your ip in app  

使用java对应的接口查询目前的ip，包括wifi的ip和移动数据网络的ip，不一定每次能够查到所有的ip，与系统是否开启wifi、是否开启移动网络等相关。

```java
    public static List<String> getIPAddress() {

        ArrayList<String> iplist = new ArrayList<String>();
        try {
            //Enumeration<NetworkInterface> en=NetworkInterface.getNetworkInterfaces();
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                NetworkInterface intf = en.nextElement();
                for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements(); ) {
                    InetAddress inetAddress = enumIpAddr.nextElement();
                    if (!inetAddress.isLoopbackAddress() && inetAddress instanceof Inet4Address) {
                        Log.d(MainActivity.class.getName(), "ip is: " + inetAddress.getHostAddress());
                        iplist.add(inetAddress.getHostAddress());
                    }
                }
            }
        } catch (SocketException e) {
            e.printStackTrace();
        }

        return iplist;
    }
    
```

参考: https://www.cnblogs.com/anni-qianqian/p/8084656.html
