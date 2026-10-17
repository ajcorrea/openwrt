# Build OpenWrt com FullCone NAT, LuCI, tema Argon e expand_root (multi-target)

**Autor:** Alexandre Jeronimo Correa  
**GitHub:** [github.com/ajcorrea/openwrt](https://github.com/ajcorrea/openwrt)  
**E-mail:** [ajcorrea@gmail.com](mailto:ajcorrea@gmail.com)

## Resumo

O script [`build_openwrt.sh`](build_openwrt.sh) gera firmware OpenWrt para **qualquer target com partição de rootfs** (PC/VM x86, Raspberry Pi e similares). Ele usa o **ImageBuilder** e o **SDK oficiais** da release escolhida e inclui:

- FullCone NAT (`kmod-nft-fullcone`, `firewall4` com patch, `luci-app-fullcone`);
- LuCI completo (`uhttpd`, `rpcd-mod-luci`, `luci-ssl`);
- tema Argon 3.0.0 como padrão, com tradução pt-BR;
- pacotes extras (collectd, vnstat2, nlbwmon, tcpdump, nmap etc.);
- expand_root: no 1º boot, a rootfs passa a ocupar o disco/SD inteiro.

Targets já gerados e validados por este script (release 25.12.5):

| Equipamento | Target/Subtarget | Profile | Arquitetura |
|---|---|---|---|
| PC / mini-PC / VM x86 64 bits | `x86/64` | `generic` | `x86_64` |
| Raspberry Pi 4B / 400 / CM4 | `bcm27xx/bcm2711` | `rpi-4` | `aarch64_cortex-a72` (ARMv8) |

## Instalação do script

```sh
mkdir -p ~/openwrt && cd ~/openwrt
curl -fLO https://raw.githubusercontent.com/ajcorrea/openwrt/main/build_openwrt.sh
chmod +x build_openwrt.sh
```

Tudo (downloads, `work/`, `tmp/`, `images/`) é criado dentro da pasta onde o script está. Você pode renomear o arquivo (ex.: `build.sh`): a ajuda e as mensagens usam o nome real.

## Uso

```text
./build_openwrt.sh <VERSÃO> <TARGET/SUBTARGET> [PROFILE]
```

O **1º argumento é sempre a versão**. Se você começar direto pelo target (ex.: `./build_openwrt.sh x86/64 generic`), o script avisa e usa a versão padrão (25.12.5).

### Exemplo 1 — x86 64 bits (PC, mini-PC, Proxmox, VMware, VirtualBox)

```sh
./build_openwrt.sh 25.12.5 x86/64 generic
```

Imagens principais em `images/`:

- `openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz` (boot UEFI);
- `openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined.img.gz` (boot BIOS/legacy).

### Exemplo 2 — Raspberry Pi 4 Model B / 400 / CM4 (64 bits)

```sh
./build_openwrt.sh 25.12.5 bcm27xx/bcm2711 rpi-4
```

Imagens principais em `images/`:

- `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-factory.img.gz` (gravar no cartão SD);
- `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz` (atualizar um Pi que já roda OpenWrt).

### Outras formas de chamar

```sh
# TARGET e SUBTARGET separados (equivale aos exemplos acima)
./build_openwrt.sh 25.12.5 x86 64 generic
./build_openwrt.sh 25.12.5 bcm27xx bcm2711 rpi-4

# Nova release: só troque a versão
./build_openwrt.sh 25.12.6 x86/64 generic
./build_openwrt.sh 25.12.6 bcm27xx/bcm2711 rpi-4
```

- Se você não informar o profile, o script usa o padrão conhecido (`x86/64 -> generic`, `bcm27xx/bcm2711 -> rpi-4`).
- Sem nenhum argumento, ele gera `25.12.5 bcm27xx/bcm2711 rpi-4`. Esse padrão foi mantido por compatibilidade; prefira informar versão e target.
- Para descobrir o target e o profile de outro equipamento, use `--list-profiles` (seção abaixo).

### Ajuda, dependências e validação

```sh
./build_openwrt.sh --help          # ajuda completa
./build_openwrt.sh --check-deps    # só verifica as dependências (não compila)

# Valida imagens já geradas, sem refazer o build
./build_openwrt.sh --validate 25.12.5 x86/64 generic
./build_openwrt.sh --validate 25.12.5 bcm27xx/bcm2711 rpi-4
```

O script sempre verifica as dependências antes de começar. Se faltar alguma, ele lista cada item faltante (comando ou biblioteca de desenvolvimento e o pacote correspondente), mostra o comando de instalação pronto para a sua distro (apt, dnf, pacman ou zypper) e para — **nada é instalado automaticamente**. Instale com o comando mostrado e rode o script de novo.

A validação lê o rootfs **de dentro da imagem squashfs gerada** (`squashfs-combined.img.gz` no x86, `squashfs-sysupgrade.img.gz` no Raspberry Pi). Ela confere o manifest, os pacotes obrigatórios e os scripts `70-rootpt-resize`, `80-rootfs-resize` e `99-argon-default`. Se falhar, grava `tmp/validate/diagnostico.txt` (versão do unsquashfs, offset da partição, `uci-defaults` encontrados, conteúdo de `files/`).

## Imagens geradas para x86/64

`x86/64` é o único target x86 de 64 bits. `x86/generic`, `x86/legacy` e `x86/geode` são de 32 bits.

| Arquivo (`openwrt-<versão>-fullcone-argon-extra-expandroot-x86-64-generic-…`) | Uso |
|---|---|
| `squashfs-combined-efi.img.gz` | **Recomendado**: PC/VM com boot UEFI (permite reset de fábrica) |
| `squashfs-combined.img.gz` | PC/VM com boot BIOS/legacy |
| `ext4-combined-efi.img.gz` / `ext4-combined.img.gz` | Mesmo uso, rootfs ext4 (gravável, sem reset de fábrica) |
| `*-rootfs.img.gz`, `kernel.bin`, `rootfs.tar.gz` | Uso avançado (ex.: container/LXC no Proxmox) |

As imagens `combined` servem tanto para gravar no disco (`dd`, ou converter para VM com `qemu-img convert`) quanto para `sysupgrade`. A validação final do script lê o rootfs de dentro da `squashfs-combined.img.gz`.

Gravar num disco/SSD (troque `/dev/sdX` pelo disco correto — **apaga tudo**):

```sh
gunzip -c openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Converter para disco de VM (Proxmox/QEMU):

```sh
gunzip -k openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz
qemu-img convert -f raw -O qcow2 openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img openwrt-x86-64.qcow2
```

Downloads interrompidos não quebram mais o build: o SDK e o ImageBuilder são baixados para `.part` e conferidos com o `sha256sums` oficial. Um arquivo incompleto que já esteja em `work/` é detectado e baixado de novo.

## Listar os profiles de uma plataforma (`--list-profiles`)

Antes do build, descubra o target e o nome exato do profile do seu equipamento. O script lê os JSON oficiais da release (`.overview.json` e `profiles.json`). Ele não baixa SDK nem ImageBuilder e não exige as dependências de compilação (só `curl` e `python3`).

| Comando | O que mostra |
|---|---|
| `--list-profiles` | Todos os targets da release padrão (25.12.5), com nº de profiles |
| `--list-profiles 25.12.6` | Todos os targets da release informada |
| `--list-profiles 25.12.5 x86/64` | Profiles de um target específico |
| `--list-profiles 25.12.5 all` | Todos os profiles de todos os targets (~1900) |

```sh
# 1) ver todos os targets
./build_openwrt.sh --list-profiles 25.12.5

# 2) procurar seu equipamento em todos os profiles
./build_openwrt.sh --list-profiles 25.12.5 all | grep -i "raspberry pi 4"

# 3) ver os profiles de um target
./build_openwrt.sh --list-profiles 25.12.5 x86/64
./build_openwrt.sh --list-profiles 25.12.5 bcm27xx bcm2711
```

Saída de exemplo (todos os targets, trecho):

```text
[INFO] Targets disponíveis no OpenWrt 25.12.5
TARGET/SUBTARGET     | PROFILES
---------------------+---------
apm821xx/nand        | 5
...
bcm27xx/bcm2711      | 1
...
mediatek/filogic     | 170
...
x86/64               | 1

Total: 90 target(s) | 1932 profile(s)
```

Saída de exemplo (profiles de um target):

```text
[INFO] Profiles para OpenWrt 25.12.5 | target=x86 | subtarget=64
PROFILE | DISPOSITIVO(S)
--------+-------------------------------
generic | Generic x86/64

Total: 1 profile(s)
Exemplo: ./build_openwrt.sh 25.12.5 x86/64 generic
```

Se a plataforma não existir na release, o script mostra a URL consultada e o link da lista de targets: `https://downloads.openwrt.org/releases/<versão>/targets/`.

> Atenção: o expand_root e a validação final foram feitos para imagens com partição de rootfs (x86, Raspberry Pi). Em roteadores com flash NAND/NOR (ex.: `mediatek/filogic`), o build pode precisar de ajustes. Lá não existem as imagens `squashfs-combined`/`squashfs-sysupgrade` que a validação procura.

O script automaticamente:
1. baixa SDK + ImageBuilder da versão informada;
2. recompila FullCone e Argon;
3. embute pacotes extras;
4. adiciona scripts de `expand_root` no primeiro boot;
5. gera as imagens em `images/` (`combined` no x86, `factory/sysupgrade` no Raspberry Pi);
6. executa validação final automática (manifest + pacotes obrigatórios + presença dos scripts `uci-defaults` no rootfs).

## Sobre o pacote solicitado (`openwrt-sonic-fullcone`)

O repositório informado (`github.com/akorshun/fullcone-openwrt`) não expõe um pacote com nome literal `openwrt-sonic-fullcone`; ele entrega o FullCone via conjunto de pacotes, principalmente:

- `kmod-nft-fullcone`
- `luci-app-fullcone`
- `firewall4` (patch para suporte fullcone)
- `libnftnl11` (patch)
- `nftables-json` (patch)

Esses pacotes são compilados no **SDK oficial do target escolhido** (ex.: `x86/64`, `bcm27xx/bcm2711`) e injetados no ImageBuilder. O módulo do kernel só funciona com o kernel exato da release/target em que foi compilado.

## Evidência de inclusão no firmware

Manifesto da imagem do Raspberry Pi 4 (25.12.5):

`images/openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4.manifest`

Entradas relevantes presentes:

- `firewall4 - 2025.03.17~b6e51575-r202`
- `kmod-nft-fullcone - 6.12.94.2023.05.17~07d93b62-r3`
- `libnftnl11 - 1.3.1-r201`
- `luci-app-fullcone - 26.278.52999~fa29808`
- `nftables-json - 1.1.6-r202`

No manifest do x86/64 (`images/openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic.manifest`), os mesmos pacotes aparecem com revisões `r101/r102` (`firewall4 - 2025.03.17~b6e51575-r102`, `kmod-nft-fullcone - 6.12.94.2023.05.17~07d93b62-r3`). As versões oficiais da release são `r2`; uma revisão maior indica que o pacote com patch foi o usado.

## Arquivos de firmware gerados

Diretório de saída:

`images/`

### Raspberry Pi 4 (FullCone + Argon + pacotes extras + expand_root)

1. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade.img.gz`
2. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz`
3. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-ext4-factory.img.gz`
4. `openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-factory.img.gz`

> As imagens `-argon-`, `-webui-` e sem sufixo são de builds anteriores.
>
> Para as imagens x86/64, veja a seção "Imagens geradas para x86/64" acima.

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
gzip -dc openwrt-25.12.5-fullcone-argon-extra-expandroot-bcm27xx-bcm2711-rpi-4-squashfs-factory.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
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

No x86/64 é igual, com a imagem `combined` (use `-efi` se o equipamento instalado hoje dá boot em UEFI):

```sh
scp -O openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz root@192.168.1.1:/tmp/
sysupgrade -T /tmp/openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz
sysupgrade -v /tmp/openwrt-25.12.5-fullcone-argon-extra-expandroot-x86-64-generic-squashfs-combined-efi.img.gz
```

## Pacotes adicionais incluídos nesta imagem

Foram embutidos os pacotes adicionais solicitados (monitoramento/rede/ferramentas), incluindo: `collectd` (+ módulos CPU/Memória/Network/Interface/IWInfo/RRD), `vnstat2` + `luci-app-vnstat2`, `nlbwmon` + `luci-app-nlbwmon`, `luci-app-statistics`, `luci-app-upnp`, `luci-app-wol`, `miniupnpd-nftables`, `curl`, `tcpdump`, `htop`, `iftop`, `iperf3`, `nmap-full`, `mtr-nojson`, `parted`, `losetup`, `resize2fs`, entre outros.

## Expansão automática para usar todo o disco ou cartão SD (expand_root)

Para aplicar o procedimento do guia `expand_root` no primeiro boot, a imagem já inclui:

- `/etc/uci-defaults/70-rootpt-resize`
- `/etc/uci-defaults/80-rootfs-resize`

Esses scripts usam `parted + losetup + resize2fs` e fazem reboot automático durante a expansão.

### Comportamento esperado no primeiro boot

1. Sobe normalmente.
2. Executa `70-rootpt-resize` e reinicia.
3. Executa `80-rootfs-resize` e reinicia novamente.
4. Na terceira subida, o rootfs já está expandido para ocupar todo o disco (x86) ou cartão SD (Raspberry Pi).

### Como validar após instalar

```sh
df -h /
lsblk
cat /etc/rootpt-resize /etc/rootfs-resize
```

Se os arquivos `/etc/rootpt-resize` e `/etc/rootfs-resize` existem, a expansão foi concluída.

## Fontes e componentes oficiais utilizados

- Releases OpenWrt: `https://downloads.openwrt.org/releases/`
- ImageBuilder e SDK oficiais de cada release/target, baixados de `https://downloads.openwrt.org/releases/<versão>/targets/<target>/<subtarget>/` e conferidos com o `sha256sums` oficial
- Repositório FullCone: `https://github.com/akorshun/fullcone-openwrt`

## Observações

- O build usa os pacotes do repositório `akorshun/fullcone-openwrt`, compilados no SDK oficial de cada target.
- As revisões maiores dos pacotes com patch (`r1xx/r2xx`, contra `r2` na release oficial) garantem prioridade sobre os pacotes padrão na composição da imagem.
