#!/usr/bin/env bash
# =============================================================================
#  build_release_fullcone_rpi4.sh
#  OpenWrt para Raspberry Pi 4 com FullCone NAT, tema Argon e expand_root
#
#  Autor:  Alexandre Jeronimo Correa
#  GitHub: github.com/ajcorrea/openwrt
#  E-mail: ajcorrea@gmail.com
# =============================================================================
set -euo pipefail

# sfdisk/unsquashfs ficam em /sbin ou /usr/sbin em algumas distros (ex.: Debian)
export PATH="${PATH}:/usr/sbin:/sbin"

print_help() {
  cat <<'EOF'
Uso:
  ./build_release_fullcone_rpi4.sh [RELEASE] [TARGET] [SUBTARGET] [PROFILE]

Exemplos:
  ./build_release_fullcone_rpi4.sh
  ./build_release_fullcone_rpi4.sh 25.12.6
  ./build_release_fullcone_rpi4.sh 25.12.6 bcm27xx bcm2711 rpi-4

Padrões:
  RELEASE   = 25.12.5
  TARGET    = bcm27xx
  SUBTARGET = bcm2711
  PROFILE   = rpi-4

O que o script faz:
  1) Baixa ImageBuilder + SDK da release
  2) Compila FullCone + Argon (pt-BR)
  3) Gera imagem com pacotes extras
  4) Injeta scripts de expand_root no 1º boot
  5) Executa validação final automática

Opções:
  -h, --help     Mostra esta ajuda
  --check-deps   Só verifica as dependências do sistema e sai
  --validate [RELEASE] [TARGET] [SUBTARGET] [PROFILE]
                 Só valida as imagens já geradas em images/ (sem rebuild).
                 Em caso de falha, grava tmp/validate/diagnostico.txt

Antes de compilar, o script verifica as dependências. Se faltar alguma,
ele lista o que falta, mostra o comando de instalação para a sua distro
e para (nada é instalado automaticamente).
EOF
}

# ---------------------------------------------------------------------------
# Dependências: "tipo:alvo|apt|dnf|pacman|zypper"
#   tipo cmd -> verifica se o comando existe no PATH
#   tipo hdr -> verifica se o header C existe (bibliotecas de desenvolvimento)
# ---------------------------------------------------------------------------
DEPS=(
  "cmd:curl|curl|curl|curl|curl"
  "cmd:wget|wget|wget|wget|wget"
  "cmd:git|git|git|git|git"
  "cmd:make|build-essential|make|base-devel|make"
  "cmd:gcc|build-essential|gcc|base-devel|gcc"
  "cmd:g++|build-essential|gcc-c++|base-devel|gcc-c++"
  "cmd:gawk|gawk|gawk|gawk|gawk"
  "cmd:awk|gawk|gawk|gawk|gawk"
  "cmd:sed|sed|sed|sed|sed"
  "cmd:grep|grep|grep|grep|grep"
  "cmd:find|findutils|findutils|findutils|findutils"
  "cmd:xargs|findutils|findutils|findutils|findutils"
  "cmd:sha256sum|coreutils|coreutils|coreutils|coreutils"
  "cmd:tar|tar|tar|tar|tar"
  "cmd:xz|xz-utils|xz|xz|xz"
  "cmd:zstd|zstd|zstd|zstd|zstd"
  "cmd:bzip2|bzip2|bzip2|bzip2|bzip2"
  "cmd:unzip|unzip|unzip|unzip|unzip"
  "cmd:patch|patch|patch|patch|patch"
  "cmd:diff|diffutils|diffutils|diffutils|diffutils"
  "cmd:perl|perl|perl|perl|perl"
  "cmd:python3|python3|python3|python|python3"
  "cmd:rsync|rsync|rsync|rsync|rsync"
  "cmd:file|file|file|file|file"
  "cmd:msgfmt|gettext|gettext|gettext|gettext-tools"
  "cmd:xsltproc|xsltproc|libxslt|libxslt|libxslt-tools"
  "cmd:unsquashfs|squashfs-tools|squashfs-tools|squashfs-tools|squashfs"
  "cmd:gzip|gzip|gzip|gzip|gzip"
  "cmd:sfdisk|fdisk|util-linux|util-linux|util-linux"
  "hdr:ncurses.h|libncurses-dev|ncurses-devel|ncurses|ncurses-devel"
  "hdr:zlib.h|zlib1g-dev|zlib-devel|zlib|zlib-devel"
  "hdr:openssl/ssl.h|libssl-dev|openssl-devel|openssl|libopenssl-devel"
)

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v zypper >/dev/null 2>&1; then echo zypper
  else echo unknown
  fi
}

header_exists() {
  # Usa o compilador para achar o header; sem gcc, procura nos diretórios padrão
  local hdr="$1"
  if command -v gcc >/dev/null 2>&1; then
    echo "#include <${hdr}>" | gcc -E -x c - >/dev/null 2>&1
  else
    [[ -f "/usr/include/${hdr}" || -f "/usr/local/include/${hdr}" ]]
  fi
}

check_dependencies() {
  local pm col entry spec kind target pkg
  local -a missing_items=() missing_pkgs=()
  pm="$(detect_pkg_manager)"
  case "$pm" in
    apt) col=2 ;; dnf) col=3 ;; pacman) col=4 ;; zypper) col=5 ;; *) col=2 ;;
  esac

  echo "[INFO] Verificando dependências (gerenciador de pacotes: ${pm})..."

  for entry in "${DEPS[@]}"; do
    spec="${entry%%|*}"
    kind="${spec%%:*}"
    target="${spec#*:}"
    pkg="$(echo "$entry" | cut -d'|' -f"$col")"

    if [[ "$kind" == "cmd" ]]; then
      command -v "$target" >/dev/null 2>&1 && continue
      missing_items+=("comando: ${target} | pacote: ${pkg}")
    else
      header_exists "$target" && continue
      missing_items+=("header: ${target} | pacote: ${pkg}")
    fi

    # evita pacote repetido na lista de instalação
    [[ " ${missing_pkgs[*]:-} " == *" ${pkg} "* ]] || missing_pkgs+=("$pkg")
  done

  if [[ ${#missing_items[@]} -eq 0 ]]; then
    echo "[OK] Todas as dependências estão instaladas."
    return 0
  fi

  echo
  echo "[ERRO] Faltam ${#missing_items[@]} dependência(s):"
  printf '  - %s\n' "${missing_items[@]}"
  echo
  echo "Instale com o comando abaixo e rode o script novamente:"
  echo
  case "$pm" in
    apt)    echo "  sudo apt-get update && sudo apt-get install -y ${missing_pkgs[*]}" ;;
    dnf)    echo "  sudo dnf install -y ${missing_pkgs[*]}" ;;
    pacman) echo "  sudo pacman -S --needed ${missing_pkgs[*]}" ;;
    zypper) echo "  sudo zypper install -y ${missing_pkgs[*]}" ;;
    *)      echo "  (gerenciador de pacotes não reconhecido; nomes no padrão Debian/Ubuntu)"
            echo "  ${missing_pkgs[*]}" ;;
  esac
  echo
  return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

if [[ "${1:-}" == "--check-deps" ]]; then
  check_dependencies && exit 0 || exit 1
fi

# --validate: só valida imagens já geradas (não baixa nem compila nada)
VALIDATE_ONLY=0
if [[ "${1:-}" == "--validate" ]]; then
  VALIDATE_ONLY=1
  shift
fi

# Verifica dependências antes de qualquer download/compilação
check_dependencies || exit 1

RELEASE="${1:-25.12.5}"
TARGET="${2:-bcm27xx}"
SUBTARGET="${3:-bcm2711}"
PROFILE="${4:-rpi-4}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${ROOT_DIR}/work"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
APK_DIR="${ARTIFACTS_DIR}/apk"
IMAGES_DIR="${ROOT_DIR}/images"
FILES_DIR="${ROOT_DIR}/files"
FULLCONE_REPO="${ROOT_DIR}/fullcone-openwrt"
ARGON_REPO="${ROOT_DIR}/luci-theme-argon"
TARGET_URL="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/${SUBTARGET}"
EXTRA_NAME="fullcone-argon-extra-expandroot"
IMAGE_PREFIX="openwrt-${RELEASE}-${EXTRA_NAME}-${TARGET}-${SUBTARGET}-${PROFILE}"

# Diretório temporário local, dentro da pasta do script (ROOT_DIR)
TMPDIR="${ROOT_DIR}/tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$WORK_DIR" "$ARTIFACTS_DIR" "$APK_DIR" "$IMAGES_DIR" "$FILES_DIR/etc/uci-defaults"
echo "[INFO] ROOT_DIR=${ROOT_DIR} | TMPDIR=${TMPDIR}"

find_release_artifact() {
  local prefix="$1"
  local page
  page="$(curl -fsSL "$TARGET_URL/")"
  echo "$page" \
    | tr '"' '\n' \
    | grep -E "^${prefix}.*\.tar\.(xz|zst)$" \
    | head -n1
}

extract_archive() {
  local archive="$1"
  local outdir="$2"
  rm -rf "$outdir"
  mkdir -p "$outdir"
  if [[ "$archive" == *.tar.zst ]]; then
    tar --zstd -xf "$archive" -C "$outdir" --strip-components=1
  else
    tar -xf "$archive" -C "$outdir" --strip-components=1
  fi
}

prepare_custom_files() {
  cat > "${FILES_DIR}/etc/uci-defaults/70-rootpt-resize" <<'EOF'
#!/bin/sh

if [ ! -e /etc/rootpt-resize ] \
&& type parted > /dev/null \
&& lock -n /var/lock/root-resize
then
ROOT_BLK="$(readlink -f /sys/dev/block/"$(awk -e '$9=="/dev/root"{print $3}' /proc/self/mountinfo)")"
ROOT_DISK="/dev/$(basename "${ROOT_BLK%/*}")"
ROOT_PART="${ROOT_BLK##*[^0-9]}"
parted -f -s "${ROOT_DISK}" resizepart "${ROOT_PART}" 100%
mount_root done
touch /etc/rootpt-resize

ROOT="/dev/$(basename "${ROOT_BLK}")"
[ -f "/boot/cmdline.txt" ] && \
grep -q "root=PARTUUID" /boot/cmdline.txt && \
sed -i "s_root=PARTUUID=[^ ]\+_root=${ROOT}_" /boot/cmdline.txt

rm /etc/uci-defaults/70-rootpt-resize
reboot
fi
EOF

  cat > "${FILES_DIR}/etc/uci-defaults/80-rootfs-resize" <<'EOF'
#!/bin/sh

if [ ! -e /etc/rootfs-resize ] \
&& [ -e /etc/rootpt-resize ] \
&& type losetup > /dev/null \
&& type resize2fs > /dev/null \
&& lock -n /var/lock/root-resize
then
ROOT_BLK="$(readlink -f /sys/dev/block/"$(awk -e '$9=="/dev/root"{print $3}' /proc/self/mountinfo)")"
ROOT_DEV="/dev/${ROOT_BLK##*/}"
LOOP_DEV="$(awk -e '$5=="/overlay"{print $9}' /proc/self/mountinfo)"
if [ -z "${LOOP_DEV}" ]
then
  LOOP_DEV="$(losetup -f)"
  losetup "${LOOP_DEV}" "${ROOT_DEV}"
fi

resize2fs -f "${LOOP_DEV}"
mount_root done
touch /etc/rootfs-resize

ROOT="/dev/$(basename "${ROOT_BLK}")"
[ -f "/boot/cmdline.txt" ] && \
grep -q "root=PARTUUID" /boot/cmdline.txt && \
sed -i "s_root=PARTUUID=[^ ]\+_root=${ROOT}_" /boot/cmdline.txt

rm /etc/uci-defaults/80-rootfs-resize
reboot
else
  exit 1
fi
EOF

  cat > "${FILES_DIR}/etc/uci-defaults/99-argon-default" <<'EOF'
#!/bin/sh
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci
exit 0
EOF

  chmod +x "${FILES_DIR}/etc/uci-defaults/70-rootpt-resize" \
           "${FILES_DIR}/etc/uci-defaults/80-rootfs-resize" \
           "${FILES_DIR}/etc/uci-defaults/99-argon-default"
}

download_and_prepare_toolchains() {
  local ib_name sdk_name
  ib_name="$(find_release_artifact "openwrt-imagebuilder-${RELEASE}-${TARGET}-${SUBTARGET}\\.Linux-x86_64")"
  sdk_name="$(find_release_artifact "openwrt-sdk-${RELEASE}-${TARGET}-${SUBTARGET}_[^\"]*\\.Linux-x86_64")"

  if [[ -z "$ib_name" || -z "$sdk_name" ]]; then
    echo "[ERRO] Não encontrei ImageBuilder/SDK para ${RELEASE} em ${TARGET_URL}" >&2
    exit 1
  fi

  echo "[INFO] ImageBuilder: ${ib_name}"
  echo "[INFO] SDK: ${sdk_name}"

  [[ -f "${WORK_DIR}/${ib_name}" ]] || curl -fL "${TARGET_URL}/${ib_name}" -o "${WORK_DIR}/${ib_name}"
  [[ -f "${WORK_DIR}/${sdk_name}" ]] || curl -fL "${TARGET_URL}/${sdk_name}" -o "${WORK_DIR}/${sdk_name}"

  IB_DIR="${WORK_DIR}/openwrt-imagebuilder-${RELEASE}-${TARGET}-${SUBTARGET}.Linux-x86_64"
  SDK_DIR="${WORK_DIR}/openwrt-sdk-${RELEASE}-${TARGET}-${SUBTARGET}.Linux-x86_64"

  extract_archive "${WORK_DIR}/${ib_name}" "${IB_DIR}"
  extract_archive "${WORK_DIR}/${sdk_name}" "${SDK_DIR}"

  export IB_DIR SDK_DIR
}

prepare_sources() {
  if [[ ! -d "$FULLCONE_REPO/.git" ]]; then
    git clone https://github.com/akorshun/fullcone-openwrt.git "$FULLCONE_REPO"
  else
    git -C "$FULLCONE_REPO" pull --ff-only
  fi

  if [[ ! -d "$ARGON_REPO/.git" ]]; then
    git clone https://github.com/jerrykuku/luci-theme-argon.git "$ARGON_REPO"
  else
    git -C "$ARGON_REPO" pull --ff-only
  fi
}

build_custom_apks() {
  cd "$SDK_DIR"

  cp feeds.conf.default feeds.conf
  grep -q '^src-link fullcone ' feeds.conf || echo "src-link fullcone ${FULLCONE_REPO}/package" >> feeds.conf

  ./scripts/feeds update -a
  sh "${FULLCONE_REPO}/scripts/apply-overlay.sh" "${FULLCONE_REPO}/overlay"

  rm -rf package/luci-theme-argon
  cp -a "$ARGON_REPO" package/luci-theme-argon

  ./scripts/feeds update -i
  ./scripts/feeds install -a

  cat > .config <<'EOF'
CONFIG_PACKAGE_kmod-nft-fullcone=m
CONFIG_PACKAGE_libnftnl=m
CONFIG_PACKAGE_nftables-json=m
CONFIG_PACKAGE_nftables-nojson=m
CONFIG_PACKAGE_firewall4=m
CONFIG_PACKAGE_luci-app-fullcone=m
CONFIG_PACKAGE_luci-theme-argon=m
CONFIG_PACKAGE_luci-i18n-argon-config-pt-br=m
CONFIG_BUILD_LOG=y
EOF

  make defconfig
  make package/fullconenat-nft/compile \
       package/libnftnl/compile \
       package/nftables/compile \
       package/firewall4/compile \
       package/luci-app-fullcone/compile \
       package/luci-theme-argon/compile \
       -j"$(nproc)" V=sc

  rm -f "${APK_DIR}"/*.apk
  for p in kmod-nft-fullcone libnftnl11 nftables-json nftables-nojson firewall4 luci-app-fullcone luci-theme-argon luci-i18n-argon-config-pt-br; do
    find bin -name "$p-*.apk" -exec cp -v {} "${APK_DIR}/" \;
  done

  (cd "${APK_DIR}" && sha256sum *.apk > sha256sums.txt)
}

build_firmware_image() {
  cd "$IB_DIR"
  mkdir -p packages
  cp -fv "${APK_DIR}"/*.apk packages/
  make package_index

  CORE_PACKAGES="luci luci-ssl uhttpd uhttpd-mod-ubus rpcd rpcd-mod-luci cgi-io luci-theme-argon luci-i18n-argon-config-pt-br kmod-nft-fullcone luci-app-fullcone firewall4 libnftnl11 nftables-json -nftables"
  EXTRA_PACKAGES="blkid collectd collectd-mod-cpu collectd-mod-interface collectd-mod-iwinfo collectd-mod-load collectd-mod-memory collectd-mod-network collectd-mod-rrdtool curl etherwake htop iftop iperf3 kmod-nf-conntrack-netlink libatomic1 libcap-ng libcurl4 libgd libiperf3 libjpeg-turbo libltdl7 liblua5.1.5 liblua5.4-5.4 libncurses6 libnghttp2-14 libopenssl3 libparted libpcap1 libpcre2 libpng libreadline8 librrd1 libsqlite3-0 libssh2-1 libstdcpp6 libwebp losetup luci-app-nlbwmon luci-app-statistics luci-app-upnp luci-app-vnstat2 luci-app-wol luci-lib-chartjs luci-lib-jsonc miniupnpd-nftables mtr-nojson nlbwmon nmap-full parted resize2fs rrdtool1 tcpdump terminfo vnstat2 vnstati2"
  PACKAGES="${CORE_PACKAGES} ${EXTRA_PACKAGES}"

  make manifest PROFILE="$PROFILE" PACKAGES="$PACKAGES"
  make image PROFILE="$PROFILE" BIN_DIR="$IMAGES_DIR" EXTRA_IMAGE_NAME="$EXTRA_NAME" FILES="$FILES_DIR" PACKAGES="$PACKAGES"

  cp -fv "${IMAGES_DIR}"/*.manifest "${ROOT_DIR}/" || true
}

validate_outputs() {
  echo "[INFO] Validação final..."

  local manifest="${IMAGES_DIR}/${IMAGE_PREFIX}.manifest"
  local sqfs_img="${IMAGES_DIR}/${IMAGE_PREFIX}-squashfs-sysupgrade.img.gz"
  local ext4_img="${IMAGES_DIR}/${IMAGE_PREFIX}-ext4-sysupgrade.img.gz"

  [[ -f "$manifest" ]] || { echo "[ERRO] Manifest não encontrado: $manifest"; exit 1; }
  [[ -f "$sqfs_img" ]] || { echo "[ERRO] Imagem squashfs sysupgrade não encontrada"; exit 1; }
  [[ -f "$ext4_img" ]] || { echo "[ERRO] Imagem ext4 sysupgrade não encontrada"; exit 1; }

  local required_pkgs=(
    kmod-nft-fullcone
    luci-app-fullcone
    luci-theme-argon
    luci-i18n-argon-config-pt-br
    parted
    losetup
    resize2fs
    uhttpd
    rpcd-mod-luci
  )

  for pkg in "${required_pkgs[@]}"; do
    grep -q "^${pkg} - " "$manifest" || { echo "[ERRO] Pacote ausente no manifest: ${pkg}"; exit 1; }
  done

  # Valida o rootfs DENTRO da imagem entregue (não um arquivo intermediário do build_dir).
  # Tudo fica em arquivos no TMPDIR (sem pipes com grep -q) e é mantido para diagnóstico.
  local vdir="${TMPDIR}/validate"
  local raw_img="${vdir}/squashfs-sysupgrade.img"
  local list_file="${vdir}/rootfs-list.txt"
  local err_file="${vdir}/unsquashfs-stderr.txt"
  local diag_file="${vdir}/diagnostico.txt"
  rm -rf "$vdir"; mkdir -p "$vdir"

  # gzip retorna 2 por causa dos metadados que o OpenWrt anexa ao fim do .img.gz (esperado)
  local gz_rc=0
  gzip -dc "$sqfs_img" > "$raw_img" 2>"${vdir}/gzip-stderr.txt" || gz_rc=$?
  if [[ $gz_rc -ne 0 && $gz_rc -ne 2 ]]; then
    echo "[ERRO] Falha ao descompactar ${sqfs_img} (gzip rc=${gz_rc})"; exit 1
  fi

  local part_start
  part_start="$(sfdisk -d "$raw_img" 2>/dev/null | awk -F'[=,]' '$1 ~ /img2 *: *start/ {gsub(/ /,"",$2); print $2}')"
  if [[ -z "$part_start" ]]; then
    echo "[ERRO] Não achei a partição 2 (rootfs) na imagem. Tabela de partições:"
    sfdisk -d "$raw_img" || true
    exit 1
  fi
  local offset=$(( part_start * 512 ))

  local us_rc=0
  unsquashfs -o "$offset" -l "$raw_img" > "$list_file" 2>"$err_file" || us_rc=$?

  local missing=()
  for f in 70-rootpt-resize 80-rootfs-resize 99-argon-default; do
    grep -q "etc/uci-defaults/${f}\$" "$list_file" || missing+=("$f")
  done

  if [[ $us_rc -ne 0 || ${#missing[@]} -gt 0 ]]; then
    {
      echo "== Diagnóstico da validação do rootfs =="
      echo "imagem: ${sqfs_img}"
      echo "gzip rc: ${gz_rc} | inicio particao 2 (setores): ${part_start} | offset (bytes): ${offset}"
      echo "unsquashfs: $(command -v unsquashfs) | versao: $(unsquashfs -version 2>&1 | head -n1)"
      echo "unsquashfs rc: ${us_rc} | linhas listadas: $(wc -l < "$list_file")"
      echo "scripts ausentes: ${missing[*]:-nenhum}"
      echo "-- stderr do unsquashfs:"; head -n 20 "$err_file"
      echo "-- /etc/uci-defaults encontrados na imagem:"; grep 'etc/uci-defaults' "$list_file" || echo "(nenhum)"
      echo "-- conteudo de FILES_DIR (${FILES_DIR}/etc/uci-defaults):"; ls -la "${FILES_DIR}/etc/uci-defaults" 2>&1
      echo "-- primeiras linhas da listagem:"; head -n 5 "$list_file"
    } > "$diag_file"
    cat "$diag_file"
    echo "[ERRO] Validação do rootfs falhou. Diagnóstico salvo em: ${diag_file}"
    echo "[INFO] As imagens foram geradas em ${IMAGES_DIR}; só a verificação falhou."
    exit 1
  fi
  rm -f "$raw_img"
  echo "[OK] Scripts uci-defaults presentes no rootfs da imagem (70-rootpt-resize | 80-rootfs-resize | 99-argon-default)"

  echo "[OK] Validação final concluída com sucesso."
  echo "[OK] Manifest: $manifest"
  echo "[OK] Imagens:"
  echo "  - $sqfs_img"
  echo "  - $ext4_img"
}

main() {
  echo "[INFO] Build OpenWrt ${RELEASE} (${TARGET}/${SUBTARGET}, profile=${PROFILE})"
  prepare_custom_files
  download_and_prepare_toolchains
  prepare_sources
  build_custom_apks
  build_firmware_image
  validate_outputs
  echo "[OK] Concluído. Imagens em: ${IMAGES_DIR}"
}

if [[ $VALIDATE_ONLY -eq 1 ]]; then
  echo "[INFO] Modo --validate: ${IMAGE_PREFIX}"
  validate_outputs
  exit 0
fi

main "$@"
