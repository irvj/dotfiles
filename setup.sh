#!/bin/bash
set -e

USERNAME="irvj"
DOTFILES_REPO="https://github.com/irvj/dotfiles.git"

# --- system setup ---

apt update && apt upgrade -y
apt install -y \
  git \
  curl \
  wget \
  tmux \
  neovim \
  zsh \
  ufw \
  htop \
  unzip \
  ripgrep \
  fd-find \
  build-essential \
  fzf

# --- install starship ---

curl -sS https://starship.rs/install.sh | sh -s -- -y

# --- install lazygit ---

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
install lazygit /usr/local/bin
rm lazygit lazygit.tar.gz

# --- create user ---

adduser --disabled-password --gecos "" $USERNAME
usermod -aG sudo $USERNAME
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME

# --- copy ssh key from root ---

mkdir -p /home/$USERNAME/.ssh
cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# --- lock down ssh ---

sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# --- firewall ---

ufw allow OpenSSH
ufw --force enable

# --- set default shell to zsh ---

chsh -s $(which zsh) $USERNAME

# --- setup zsh plugins ---

sudo -u $USERNAME mkdir -p /home/$USERNAME/.zsh
sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-autosuggestions /home/$USERNAME/.zsh/zsh-autosuggestions
sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-syntax-highlighting /home/$USERNAME/.zsh/zsh-syntax-highlighting

# --- clone dotfiles ---

sudo -u $USERNAME git clone $DOTFILES_REPO /home/$USERNAME/.dotfiles

# --- run dotfiles install ---

sudo -u $USERNAME /home/$USERNAME/.dotfiles/install.sh

echo ""
echo "=========================================="
echo "done. ssh in as $USERNAME"
echo "=========================================="
