<h2 align="center">Android Subsystem for GNU/Linux</h2>

[![Repo size](https://img.shields.io/github/repo-size/Moe-hacker/asl?logo=github&logoColor=white)](https://github.com/Moe-hacker/asl)
[![TEST](https://github.com/lin1328/asl/actions/workflows/Test.yml/badge.svg)](https://github.com/lin1328/asl/actions/workflows/Test.yml)

<details>
<summary><strong>Currently Supported Systems</strong></summary>

- archlinux
  - `current`
- alpine
  - 3.20
  - `edge`
- centos
  - `9-Stream`
  - `10-Stream`
- debian
  - bullseye
  - `bookworm`
  - trixie
  - forky
- fedora
  - 39
  - `43`
- kali
  - `current`
- ubuntu
  - focal
  - `jammy`
  - noble
  - `questing`

</details>

> [!NOTE]
> - This module is only for `arm64-v8a`
> - It has been tested only on the versions marked above
> - If there are any bugs, please report them. Compatibility with all devices is not guaranteed
> - If you install the module twice, it will backup old container_dir and install a new container
> - you can install multipe OS by changeing the module id and ssh port, but this action not supported officially

## How to connect
> [!IMPORTANT]
> The default port is 22, and both the username and password are the system name. For example, "archlinux",          
> The default root user password is `J@#KmMr0@10%&x?j`, but SSH login for the root user is disabled.        
> You can also set a custom password in the `.conf` file      
> but, please change the password once you connected to the container, and it's better to use ssh key instead of password login, note that please do not expose the ssh port to the pubnet.       
## About the Binary

### Powered by ruri

- Use [ruri](https://github.com/Moe-hacker/ruri) for container runtime
- [rurima](https://github.com/Moe-hacker/rurima) is used for fetching the container rootfs
- The `file` and `curl` command are fake, they actually calls `file-static` and `curl-static` with corrected args
- Thanks: https://github.com/stunnel/static-curl for curl static binary

> [!CAUTION]
> Please change the default SSH password immediately  
> Exposing a SSH port without key-based authentication is always a high-risk action!
>
> 请修改默认密码，暴露非密钥认证而是密码认证的ssh端口无论何时都是高危行为！

> [!TIP]
> By default, you can configure the password and port in the configuration file. For ruri configuration, please refer to [ruri project](https://github.com/Moe-hacker/ruri).

---

## Thanks

- GitHub: [linqi](https://github.com/Lin1328) for the module framework
- Coolapk: 望月古川 for additional framework support
- GitHub: [stunnel](https://github.com/stunnel) for the curl static binary

## Contributing

Contributions are welcome!  
If you want to add support for other operating systems, please submit a corresponding `setup.sh`

## License

希腊奶......
