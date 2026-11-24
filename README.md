# 我的 ComfyUI 环境备忘（仙宫云 RTX 4090D 24G）

> 换实例 / 换镜像后，先跑 `bash install.sh` 把模型拉回来，再装节点，就能复原。

## 1. 运行环境

| 项 | 值 |
| --- | --- |
| ComfyUI | v0.46.2 |
| Python | `/root/miniconda3/envs/comfyui/bin/python`（3.12.7，**必须用这个**，base 环境的 3.13 会崩） |
| torch | 2.7.0+cu126（日志会警告 CUDA < 13.0，能跑但性能受限） |
| GPU | RTX 4090D，显存约 25.3 GB，内存 60 GB |
| ComfyUI 目录 | `/root/ComfyUI` |
| 访问地址 | `https://<实例域名>/`（8188 端口），Jupyter 在 8888 |

启动命令：

```bash
cd /root/ComfyUI
/root/miniconda3/envs/comfyui/bin/python main.py --listen 0.0.0.0 --port 8188
```

## 2. 启用的自定义节点（只用这 4 个）

| 包 | 用途 |
| --- | --- |
| `ComfyUI-Manager` | 管理器（V3.27.2），装/卸节点用它 |
| `rgthree-comfy` | `Image Comparer (rgthree)` 对比图、种子控制 |
| `ComfyUI-SUPIR` | `SUPIR_Upscale`（显示名 SUPIR Upscale (Legacy)）超分放大 |
| `ComfyUI-KJNodes` | `DiffusionModelLoaderKJ`、`CheckpointLoaderKJ`、`VAELoaderKJ` 等 |

> **关键**：`cg-use-everywhere` 必须保持 `.disabled`。它调用了新版前端已删除的 `GroupNodeHandler.getGroupData`，会让节点变灰块、界面卡死。
>
> 其余不需要的包统一在 `custom_nodes/` 下加 `.disabled` 后缀即可（可逆）。

## 3. 模型清单

放在 `/root/ComfyUI/models/` 下对应子目录。

### 3.1 Z-Image Turbo（文生图，8 步）

| 文件 | 目录 | 用途 |
| --- | --- | --- |
| `z_image_turbo_bf16.safetensors` | `diffusion_models/` | 扩散模型（KSampler steps 8 / cfg 1.0 / res_multistep / simple） |
| `qwen_3_4b.safetensors` | `text_encoders/` | CLIPLoader 类型选 **lumina2** |
| `ae.safetensors` | `vae/` | VAE |

### 3.2 Qwen Image 2.1（文生图）

| 文件 | 目录 |
| --- | --- |
| `qwen_image_2.1_int8_convrot.safetensors` | `diffusion_models/` |
| `qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors` | `text_encoders/` |
| `qwen_image_2.1_vae_bf16.safetensors` | `vae/` |

### 3.3 Qwen-Image-Edit-2511（图像编辑）

| 文件 | 目录 | 大小 |
| --- | --- | --- |
| `qwen_image_edit_2511_int8_convrot.safetensors` | `diffusion_models/` | 20.5 GB |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | `text_encoders/` | 约 9 GB，CLIPLoader 类型选 **qwen_image** |
| `qwen_image_vae.safetensors` | `vae/` | 约 254 MB |
| `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | `loras/` | 850 MB，4 步加速 LoRA |

工作流接法：`UNETLoader` → `LoraLoaderModelOnly`（strength 1.0）→ `TextEncodeQwenImageEditPlus`（image1~3 最多三张参考图）→ KSampler。
4 步参数：steps 4 / cfg 1.0 / euler / simple / shift 3.1；不挂 LoRA 时 steps 40 / cfg 4。

> 注意：`Qwen-Image-Lightning-8steps-V1.0`（Qwen 目录下那个）是给**文生图版** Qwen-Image 用的，不能给 Edit-2511 用。

### 3.4 SUPIR 放大（模型在 `checkpoints/` 下）

| 文件 | 目录 | 说明 |
| --- | --- | --- |
| `SUPIR/SUPIR-v0Q_fp16.safetensors` | `checkpoints/` | 通用质量版，优先用 |
| `SUPIR/SUPIR-v0F_fp16.safetensors` | `checkpoints/` | 细节保真版 |
| `sd_xl_base_1.0.safetensors` | `checkpoints/` | SUPIR 需要它做底座 |

推荐参数：`SUPIR_Upscale (Legacy)` 节点，supir_model `SUPIR-v0Q_fp16`、sdxl_model `sd_xl_base_1.0`、scale_by 2.00、resize_method lanczos、steps 25、restoration_scale -1、cfg_scale 4.0、a_prompt `high quality, detailed`、n_prompt `bad quality, blurry, messy`、s_churn 5、s_noise 1.003、control_scale 1.0、control_scale_start 0.0、cfg_scale_start 4.0、color_fix_type Wavelet、keep_model_loaded true、use_tiled_vae true、encoder_tile_size_pixels 512、decoder_tile_size_latent 64、fp8_unet true、fp8_vae true、batch_size 0、use_tiled_sampling true、sampler_tile_size 512、sampler_tile_stride 256、sampler RestoreEDMSampler。
**`diffusion_dtype` 和 `encoder_dtype` 必须填 `auto`**，填 `false` 会报「无效输入」。

## 4. 已知坑

- 前端报 `GroupNodeHandler.getGroupData is not a function` + 节点灰块 → `cg-use-everywhere` 没禁用。
- 启动报 `numpy has no attribute 'long'` → 用错 Python（跑到 base 3.13 了）。
- 老工作流弹「加载子工作流蓝图失败 x4」→ 里面内嵌了已停用插件的子图，不影响出图，建议新建工作流。
- Manager 的「Install via Git URL」会被安全等级拦住，装节点走 **Custom Nodes Manager** 搜索安装。
