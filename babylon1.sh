#!/bin/bash

# 脚本保存路径，请根据实际情况进行修改
SCRIPT_PATH="$HOME/manage_babylon.sh"

# 自动设置别名的功能
function check_and_set_alias() {
    local alias_name="babylondf"
    local shell_rc="$HOME/.bashrc"

    # 对于Zsh用户，使用.zshrc
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # 检查别名是否已经设置
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "设置别名 '$alias_name' 到 $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        echo "别名已设置。请重新打开终端或运行 'source $shell_rc' 来激活别名。"
    else
        echo "别名 '$alias_name' 已存在。"
    fi
}

# 节点安装功能
function install_node() {
    echo "开始节点安装..."
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential

    sudo rm -rf /usr/local/go
    curl -Ls https://go.dev/dl/go1.20.12.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    eval "$(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)"
    eval "$(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)"

    cd $HOME
    rm -rf babylon
    git clone https://github.com/babylonchain/babylon.git
    cd babylon
    git checkout v0.7.2

    make build

    mkdir -p $HOME/.babylond/cosmovisor/genesis/bin
    mv build/babylond $HOME/.babylond/cosmovisor/genesis/bin/
    rm -rf build

    sudo ln -s $HOME/.babylond/cosmovisor/genesis $HOME/.babylond/cosmovisor/current -f
    sudo ln -s $HOME/.babylond/cosmovisor/current/bin/babylond /usr/local/bin/babylond -f

    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest

    # 创建并启动服务
    sudo tee /etc/systemd/system/babylon.service > /dev/null <<EOF
[Unit]
Description=babylon node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.babylond"
Environment="DAEMON_NAME=babylond"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.babylond/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable babylon.service

    echo "节点安装完成。"
}

# 添加钱包
function add_wallet() {
    read -p "请输入钱包名称: " wallet_name
    babylond keys add "$wallet_name"
}

# 导入钱包
function import_wallet() {
    read -p "请输入钱包名称: " wallet_name
    babylond keys add "$wallet_name" --recover
}

# 查看节点同步状态
function check_sync_status() {
    babylond status | jq .SyncInfo
}

# 查看服务状态
function check_service_status() {
    systemctl status babylon
}

# 日志查询
function view_logs() {
    sudo journalctl -u babylon.service -f --no-hostname -o cat
}

# 主菜单
function main_menu() {
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 添加钱包"
    echo "3. 导入钱包"
    echo "4. 查看节点同步状态"
    echo "5. 查看服务状态"
    echo "6. 日志查询"
    read -p "请输入选项（1-6）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) add_wallet ;;
    3) import_wallet ;;
    4) check_sync_status ;;
    5) check_service_status ;;
    6) view_logs ;;
    *) echo "无效选项。" ;;
    esac
}

# 在脚本开始时检查并设置别名
check_and_set_alias

# 显示主菜单
main_menu