#!/bin/bash

# Runs the "6.7b" parameter model
# GPT-13B: 32 layers, 4096 hidden size, 32 attention heads

set -e

USAGE="usage: bash pretrain_6b7_megatron.sh [bf16|te|msamp]"

if [ "$#" -ne 1 ]; then
  echo $USAGE
  exit 1
fi

FP_TYPE=$1

export CUDA_DEVICE_MAX_CONNECTIONS=1
GPUS_PER_NODE=8
# Change for multinode config
MASTER_ADDR=localhost
MASTER_PORT=6000
NNODES=1
NODE_RANK=0
WORLD_SIZE=$(($GPUS_PER_NODE*$NNODES))

VOCAB_FILE=$PWD/data/gpt2-vocab.json
MERGE_FILE=$PWD/data/gpt2-merges.txt
DATA_PATH=$PWD/data/wikipedia_text_document

DISTRIBUTED_ARGS="
    --nproc_per_node $GPUS_PER_NODE \
    --nnodes $NNODES \
    --node_rank $NODE_RANK \
    --master_addr $MASTER_ADDR \
    --master_port $MASTER_PORT
"

GPT_ARGS="
    --tensor-model-parallel-size 1 \
    --pipeline-model-parallel-size 1 \
    --distributed-backend nccl \
    --no-query-key-layer-scaling \
    --seed 43 \
    --num-layers 32 \
    --hidden-size 4096 \
    --num-attention-heads 32 \
    --seq-length 2048 \
    --max-position-embeddings 2048 \
    --train-samples 48828125 \
    --lr-decay-samples 43945312  \
    --lr-warmup-samples 2048000  \
    --lr 3.0e-4 \
    --min-lr 3.0e-5 \
    --lr-decay-style cosine \
    --micro-batch-size 1 \
    --global-batch-size 2048 \
    --clip-grad 1.0 \
    --weight-decay 0.1 \
    --attention-dropout 0.0 \
    --hidden-dropout 0.0 \
    --optimizer adam \
    --adam-beta1 0.9 \
    --adam-beta2 0.95 \
    --init-method-std 0.0099 \
    --num-workers 1 \
    --bf16 \
    --sequence-parallel \
    --use-flash-attn \
    --no-gradient-accumulation-fusion \
    --use-distributed-optimizer
"


DATA_ARGS="
    --data-path $DATA_PATH \
    --vocab-file $VOCAB_FILE \
    --merge-file $MERGE_FILE \
    --data-impl mmap \
    --split 949,50,1
"

OUTPUT_ARGS="
    --log-interval 1 \
    --save-interval 1000 \
    --eval-interval 500 \
    --eval-iters 7
"

if [ "$FP_TYPE" = "bf16" ]; then
    CHECKPOINT_PATH=$PWD/checkpoints/gpt_6b7_bf16
    torchrun $DISTRIBUTED_ARGS ../third_party/Megatron-LM/pretrain_gpt.py \
        $GPT_ARGS \
        $DATA_ARGS \
        $OUTPUT_ARGS
elif [ "$FP_TYPE" = "te" ]; then
    CHECKPOINT_PATH=$PWD/checkpoints/gpt_6b7_te
    torchrun $DISTRIBUTED_ARGS ../third_party/Megatron-LM/pretrain_gpt.py \
        $GPT_ARGS \
        $DATA_ARGS \
        $OUTPUT_ARGS \
        --fp8-hybrid \
        --transformer-impl transformer_engine
elif [ "$FP_TYPE" = "msamp" ]; then
    CHECKPOINT_PATH=$PWD/checkpoints/gpt_6b7_msamp
    torchrun $DISTRIBUTED_ARGS ../third_party/Megatron-LM/pretrain_gpt.py \
        $GPT_ARGS \
        $DATA_ARGS \
        $OUTPUT_ARGS \
        --fp8-hybrid \
        --transformer-impl transformer_engine \
        --msamp
else
    echo $USAGE
    exit 1
fi
