# Build OpenWrt 25.12.5 para Raspberry Pi 4 (bcm27xx/bcm2711, armv8) com FullCone NAT

**Autor:** Alexandre Jeronimo Correa  
**GitHub:** [github.com/ajcorrea/openwrt](https://github.com/ajcorrea/openwrt)  
**E-mail:** [ajcorrea@gmail.com](mailto:ajcorrea@gmail.com)

## Resumo 

Este build foi feito com **ImageBuilder oficial do OpenWrt** para o target **bcm27xx/bcm2711** e perfil **rpi-4** (Raspberry Pi 4B/400/CM4 64 bits).

- **Versão usada:** `25.12.5` (confirmada em `https://downloads.openwrt.org/releases/`)
- **Target/Subtarget:** `bcm27xx/bcm2711`
- **Perfil:** `rpi-4`
- **Arquitetura:** `aarch64_cortex-a72` (ARMv8)

## Script único para novas versões

Use o script abaixo para gerar novamente a imagem completa quando sair uma nova release:

- Script: [`build_openwrt_raspberry_pi4b.sh`](build_openwrt_raspberry_pi4b.sh)

Baixar e dar permissão de execução:

```sh
mkdir -p ~/openwrt && cd ~/openwrt
curl -fLO https://raw.githubusercontent.com/ajcorrea/openwrt/main/build_openwrt_raspberry_pi4b.sh
chmod +x build_openwrt_raspberry_pi4b.sh
```

Tudo (downloads, `work/`, `tmp/`, `images/`) é criado dentro da pasta onde o script está.

Ajuda rápida:

```sh
./build_openwrt_raspberry_pi4b.sh --help
```

Verificar só as dependências do sistema (não compila nada):

```sh
./build_openwrt_raspberry_pi4b.sh --check-deps
```

O script sempre verifica as dependências antes de começar. Se faltar alguma, ele lista cada item faltante (comando ou biblioteca de desenvolvimento e o pacote correspondente), mostra o comando de instalação pronto para a sua distro (apt, dnf, pacman ou zypper) e para — **nada é instalado automaticamente**. Instale com o comando mostrado e rode o script de novo.

Validar imagens já geradas, sem refazer o build:

```sh
./build_openwrt_raspberry_pi4b.sh --validate 25.12.5
```

A validação lê o rootfs **de dentro da imagem `squashfs-sysupgrade.img.gz` gerada** e confere os scripts `70-rootpt-resize`, `80-rootfs-resize` e `99-argon-default`. Se falhar, grava `tmp/validate/diagnostico.txt` (versão do unsquashfs, offset da partição, `uci-defaults` encontrados, conteúdo de `files/`).

Exemplo (só mudando a versão):

```sh
./build_openwrt_raspberry_pi4b.sh 25.12.6
```

Exemplo com parâmetros explícitos:

```sh
./build_openwrt_raspberry_pi4b.sh 25.12.6 bcm27xx bcm2711 rpi-4
```

O script automaticamente:
1. baixa SDK + ImageBuilder da versão informada;
2. recompila FullCone e Argon;
3. embute pacotes extras;
4. adiciona scripts de `expand_root` no primeiro boot;
5. gera imagens `factory/sysupgrade` em `images/`;
6. executa validação final automática (manifest + pacotes obrigatórios + presença dos scripts `uci-defaults` no rootfs).

## Sobre o pacote solicitado (`openwrt-sonic-fullcone`)

O repositório informado (`github.com/akorshun/fullcone-openwrt`) não expõe um pacote com nome literal `openwrt-sonic-fullcone`; ele entrega o FullCone via conjunto de pacotes, principalmente:

- `kmod-nft-fullcone`
- `luci-app-fullcone`
- `firewall4` (patch para suporte fullcone)
- `libnftnl11` (patch)
- `nftables-json` (patch)

Esses pacotes foram compilados via **SDK oficial 25.12.5 para bcm27xx/bcm2711** e injetados no ImageBuilder.

## Evidência de inclusão no firmware

Manifesto da imagem gerada:

`images/openwrt-25.12.5-fullcone-bcm27xx-bcm2711-rpi-4.manifest`

Entradas relevantes presentes:

- `firewall4 - 2025.03.17~b6e51575-r202`
- `kmod-nft-fullcone - 6.12.94.2023.05.17~07d93b62-r3`
- `libnftnl11 - 1.3.1-r201`
- `luci-app-fullcone - 26.278.52999~fa29808`
- `nftables-json - 1.1.6-r202`

## Arquivos de firmware gerados

Diretório de saída:

`images/`

### Imagens atuais (FullCone + Argon + pacotes extras + expand_root)

1. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade.img.gz`
2. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz`
3. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-ext4-factory.img.gz`
4. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-factory.img.gz`

> As imagens `-argon-`, `-webui-` e sem sufixo são de builds anteriores.

### Tema Argon

- `luci-theme-argon` 3.0.0 (github.com/jerrykuku/luci-theme-argon, commit `539e3e1`), compilado no SDK 25.12.5, com painel de configuração integrado e tradução `luci-i18n-argon-config-pt-br`.
- O script `files/etc/uci-defaults/99-argon-default` define o Argon como tema padrão no primeiro boot (inclusive após sysupgrade mantendo configs).
- Para trocar: System → System → Language and Style.

Também foram gerados:

- `sha256sums`
- `profiles.json`
- `.manifest`

## Como gravar no Raspberry Pi 4

### Opção A: Raspberry Pi Imager
1. Abra o Raspberry Pi Imager.
2. Escolha **Use custom** / imagem personalizada.
3. Selecione o arquivo `.img.gz` desejado (factory é o mais comum para gravação inicial em SD).
4. Selecione o cartão SD.
5. Grave.

### Opção B: balenaEtcher
1. Abra o balenaEtcher.
2. Selecione o `.img.gz`.
3. Selecione o cartão SD.
4. Clique em **Flash**.

### Opção C: `dd` (Linux/macOS)
> **Atenção:** confirme o dispositivo correto (ex.: `/dev/sdX` ou `/dev/mmcblk0`) para não sobrescrever disco errado.

```bash
gzip -dc openwrt-25.12.5-fullcone-bcm27xx-bcm2711-rpi-4-ext4-factory.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

## Verificação pós-boot (no roteador)

> No OpenWrt 25.12.x, o gerenciador padrão é **apk** (não opkg).

1. Verificar pacotes (incluindo web UI):
```sh
apk info | grep -E 'luci|uhttpd|rpcd|fullcone|firewall4|nftables|libnftnl'
```

2. Verificar se o servidor web está ativo:
```sh
service uhttpd status
logread | grep -i uhttpd
```

3. Verificar módulo FullCone carregado:
```sh
lsmod | grep nft_fullcone
```

4. Habilitar FullCone NAT via UCI:
```sh
uci set firewall.@defaults[0].fullcone='1'
uci commit firewall
service firewall restart
```

5. Conferir regra nftables:
```sh
nft list chain inet fw4 srcnat_wan | grep -i fullcone
```

6. Via LuCI (se preferir):
- Network → Firewall → FullCone NAT → habilitar.

## Atualizar direto pelo SSH (sem precisar da web)
```sh
# no PC
scp -O openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz root@192.168.1.1:/tmp/
# no roteador
sysupgrade -T /tmp/openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz   # só testa
sysupgrade -v /tmp/openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz   # mantém configs
```
Use `sysupgrade -n` para apagar as configurações. Use a variante (ext4/squashfs) igual à instalada hoje.

## Pacotes adicionais incluídos nesta imagem

Foram embutidos os pacotes adicionais solicitados (monitoramento/rede/ferramentas), incluindo: `collectd` (+ módulos CPU/Memória/Network/Interface/IWInfo/RRD), `vnstat2` + `luci-app-vnstat2`, `nlbwmon` + `luci-app-nlbwmon`, `luci-app-statistics`, `luci-app-upnp`, `luci-app-wol`, `miniupnpd-nftables`, `curl`, `tcpdump`, `htop`, `iftop`, `iperf3`, `nmap-full`, `mtr-nojson`, `parted`, `losetup`, `resize2fs`, entre outros.

> Único item da sua lista que **não existe** nesse feed/build: `luci-app-argon-config` (o Argon v3 já incorpora esse painel no próprio `luci-theme-argon`).

## Expansão automática para usar todo o cartão SD (expand_root)

Para aplicar o procedimento do guia `expand_root` no primeiro boot, a imagem já inclui:

- `/etc/uci-defaults/70-rootpt-resize`
- `/etc/uci-defaults/80-rootfs-resize`

Esses scripts usam `parted + losetup + resize2fs` e fazem reboot automático durante a expansão.

### Comportamento esperado no primeiro boot

1. Sobe normalmente.
2. Executa `70-rootpt-resize` e reinicia.
3. Executa `80-rootfs-resize` e reinicia novamente.
4. Na terceira subida, o rootfs já está expandido para ocupar todo o SD.

### Como validar após instalar

```sh
df -h /
lsblk
cat /etc/rootpt-resize /etc/rootfs-resize
```

Se os arquivos `/etc/rootpt-resize` e `/etc/rootfs-resize` existem, a expansão foi concluída.

## Fontes e componentes oficiais utilizados

- Releases OpenWrt: `https://downloads.openwrt.org/releases/`
- ImageBuilder oficial 25.12.5 (bcm27xx/bcm2711)
- SDK oficial 25.12.5 (bcm27xx/bcm2711)
- Repositório FullCone: `https://github.com/akorshun/fullcone-openwrt`

## Observações

- O build foi realizado com os pacotes do repositório `akorshun/fullcone-openwrt` adaptados ao SDK oficial do target bcm2711.
- As revisões `r201/r202` dos pacotes patchados garantem prioridade sobre os pacotes padrão da release na composição da imagem.
