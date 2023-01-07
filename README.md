# Life@USTC

![Life@USTC](./Docs/Assets/Icon.png)

## 简介

项目建立的时候正是2022年疫情稍微有些严重的时候，注意到了学校各个部门的通知都很分散，学工-班主任-学生这个消息通道也不是很及时、很顺畅，导致学校的同学、老师之间多少都存在一些信息差。当然也感谢诸如小道消息等的努力，在特殊的时期给了我们不少的帮助。此外，不同的学生组织、社团也有着自己的微信公众号、QQ号，很多信息难以快速地同步、准确地送达到目标手中。

惭愧的是，22年我并没有太多时间来完成这个项目，而最开始尝试的Flutter框架对于我来说也提不起太大的兴趣，当我在年末整理代码的时候再次发现了之前的代码，于是这个项目便诞生了。

不避讳地讲，这个项目在实现的时候参考率很多“学在科大”的内容&框架，在此表示感谢。（也正好给我找了不做Android的理由，笑）在此之前我时常惊讶于为什么学在科大有那么多活跃的用户，毕竟课表、考试信息之类的似乎也有更好的办法来实现，后来我想明白了，只是单纯的懒得打开浏览器经过统一身份认证的麻烦而已。

所以这就是项目的大概来源了，如果有兴趣的话欢迎提出建议，在README的结尾你可以找到Discord的链接，虽然现在还没什么人。有任何使用上的问题也可以随时提出来，后续完善之后我们再考虑上架App Store，感谢各位的支持。

另外请注意，统一身份的认证服务并不是我们提供，而是学校提供的。目前整个项目能够正常运转的前提，也是基于对统一身份认证的简单逆向得到的。我们不能、也不会对项目的可用性和这部分安全性做出任何形式的保证。更多的注意事项请参照应用内“法律信息：统一身份认证”部分。

## 功能

- [x] 登录到统一身份认证系统，保持后台状态刷新
- [x] 在应用内集成整合官网上的不同内容
- [x] RSS消息源集成
- [x] 本科生课表
- [ ] 本科生成绩信息
- [ ] 本科生考试信息
- [ ] APN消息推送，前端内容刷新，通知用户考试信息变更等
- [ ] 社团、学生会消息推送，后端管理界面，指定推送对象
- [ ] 其他学生日常中可能用到的内容

## Build

To build this, You'll need Xcode 14.0+ and Swift 5.7+.

App Target is set to iOS 16.0+ since we face student users only.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Links

Discord: https://discord.gg/BxdsySpkYP

GitHub: https://github.com/tiankaima/Life-USTC

## Acknowledgments

Icon Source: https://pixiv.net/artworks/97582506

FeedKit: https://github.com/nmdias/FeedKit

USTC CAS: https://passport.ustc.edu.cn/
