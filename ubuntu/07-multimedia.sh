#!/usr/bin/env bash
# ubuntu/07-multimedia.sh — LibreOffice, códecs multimedia, VLC y MPV.

section 07 "MULTIMEDIA" "LibreOffice, códecs, VLC y MPV"

# --- LibreOffice (PPA oficial "fresh") ---
v_libreoffice() { pkgs_installed libreoffice-core libreoffice-l10n-es libreoffice-help-es; }
i_libreoffice() {
    sudo add-apt-repository -y ppa:libreoffice/ppa
    pkg_refresh
    pkg_install libreoffice libreoffice-l10n-es libreoffice-help-es libreoffice-style-sukapura
}
register_item libreoffice "LibreOffice (PPA) en español" v_libreoffice i_libreoffice utilidades-base

# --- Códecs y fuentes de Microsoft ---
UBUNTU_CODEC_PKGS=(ubuntu-restricted-extras ffmpeg gstreamer1.0-plugins-base gstreamer1.0-plugins-good
                   gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-vaapi)
v_codecs() { pkgs_installed "${UBUNTU_CODEC_PKGS[@]}"; }
i_codecs() {
    sudo add-apt-repository -y -n multiverse
    pkg_refresh
    # Aceptar la licencia de las fuentes de Microsoft para que la instalación no se detenga
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
    pkg_install "${UBUNTU_CODEC_PKGS[@]}"
}
register_item codecs "Códecs multimedia (ffmpeg, GStreamer, restricted-extras)" v_codecs i_codecs utilidades-base

register_pkg vlc "VLC" repo vlc vlc
register_pkg mpv "MPV" repo mpv mpv
