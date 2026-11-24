#!/usr/bin/env bash
# ComfyUI 模型一键复原（仙宫云 4090D）
# 用法：bash install.sh            # 下全部
#      bash install.sh edit2511   # 只下 Qwen-Image-Edit-2511 三件套+LoRA
#      bash install.sh supir      # 只下 SUPIR
set -e

MS=https://www.modelscope.cn/api/v1/models
ROOT=${COMFY_ROOT:-/root/ComfyUI/models}

# 通用下载函数：dl <仓库> <仓库内路径> <目标目录> <期望字节数>
dl() {
  local repo="$1" src="$2" dir="$3" want="$4"
  local name; name=$(basename "$src")
  mkdir -p "$dir"
  if [ -f "$dir/$name" ] && [ "$want" -gt 0 ] && [ "$(stat -c%s "$dir/$name")" = "$want" ]; then
    echo "[跳过] $name 已存在且大小正确"; return
  fi
  echo "[下载] $name -> $dir"
  curl -L -C - --retry 20 --retry-all-errors --progress-bar \
    -o "$dir/$name" "$MS/$repo/repo?Revision=master&FilePath=$src"
  local got; got=$(stat -c%s "$dir/$name")
  if [ "$want" -gt 0 ] && [ "$got" != "$want" ]; then
    echo "[警告] $name 大小 $got != 期望 $want，重跑本脚本可续传"; return 1
  fi
  echo "[完成] $name"
}

edit2511() {
  dl Comfy-Org/Qwen-Image-Edit_ComfyUI split_files/diffusion_models/qwen_image_edit_2511_int8_convrot.safetensors "$ROOT/diffusion_models" 20499083824
  dl Comfy-Org/Qwen-Image_ComfyUI split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors "$ROOT/text_encoders" 9384670680
  dl Comfy-Org/Qwen-Image_ComfyUI split_files/vae/qwen_image_vae.safetensors "$ROOT/vae" 253806246
  dl lightx2v/Qwen-Image-Edit-2511-Lightning Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors "$ROOT/loras" 849608296
}

supir() {
  echo "SUPIR 的三个文件（约 10 GB）在魔搭稳定性一般，建议在 ComfyUI-Manager 里按节点说明自行获取："
  echo "  models/checkpoints/SUPIR/SUPIR-v0Q_fp16.safetensors"
  echo "  models/checkpoints/SUPIR/SUPIR-v0F_fp16.safetensors"
  echo "  models/checkpoints/sd_xl_base_1.0.safetensors"
  echo "已有则跳过，无需重下。"
}

case "${1:-all}" in
  edit2511) edit2511 ;;
  supir)    supir ;;
  all)      edit2511; supir ;;
  *) echo "用法: bash install.sh [all|edit2511|supir]"; exit 1 ;;
esac

echo
echo "全部完成。回到 ComfyUI 页面按 R 刷新，检查 UNETLoader / CLIPLoader / VAELoader / LoraLoaderModelOnly 下拉里是否出现新文件。"
echo "模型目录: $ROOT"
