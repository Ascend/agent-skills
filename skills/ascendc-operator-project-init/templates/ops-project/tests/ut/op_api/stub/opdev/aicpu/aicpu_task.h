/**
 * Copyright (c) 2026 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

#ifndef OP_API_COMMON_INC_OPDEV_AICPU_AICPU_TASK_H_
#define OP_API_COMMON_INC_OPDEV_AICPU_AICPU_TASK_H_

#include <cstring>
#include <map>
#include <set>
#include <string>
#include <sys/syscall.h>
#include <unistd.h>
#include "opdev/aicpu/aicpu_args_handler.h"
#include "opdev/aicpu/aicpu_ext_info_handle.h"
#include "aclnn/aclnn_base.h"
#include "opdev/op_arg_def.h"
#include "opdev/fast_vector.h"
#include "acl/acl_rt.h"

namespace op {
namespace internal {
static constexpr size_t kAicpuKeyBufLen = 1024U;
const std::string kDefaultFunctionName = "RunCpuKernel";
void PrintAicpuAllTimeStampInfo(const char *opType);

template<typename V>
inline void AppendTensor(aclOpExecutor *executor, const aclTensor *arg, V &l)
{
    (void)executor;
    if (arg != nullptr) {
        l.emplace_back(const_cast<aclTensor *>(arg));
    }
}

template<typename V>
inline void AppendTensor(aclOpExecutor *executor, const aclScalar *arg, V &l)
{
    auto t = executor->ConvertToTensor(arg, arg->GetDataType());
    l.emplace_back(const_cast<aclTensor *>(t));
}

template<typename V>
inline void AppendTensor(aclOpExecutor *executor, const aclIntArray *arg, V &l)
{
    auto t = executor->ConvertToTensor(arg, ge::DT_INT64);
    l.emplace_back(const_cast<aclTensor *>(t));
}

template<typename V>
inline void AppendTensor(aclOpExecutor *executor, const aclTensorList *arg, V &l)
{
    (void)executor;
    for (size_t i = 0U; i < arg->Size(); i++) {
        l.emplace_back(const_cast<aclTensor *>((*arg)[i]));
    }
}

template<typename TensorList>
void CreateTensorListImpl(aclOpExecutor *executor, OpArg &arg, TensorList &l)
{
    switch (arg.type) {
        case OpArgType::OPARG_ACLTENSOR:
            AppendTensor(executor, reinterpret_cast<aclTensor *>(arg->pointer), l);
            break;
        case OpArgType::OPARG_ACLSCALAR:
            AppendTensor(executor, reinterpret_cast<aclScalar *>(arg->pointer), l);
            break;
        case OpArgType::OPARG_INT_LIST:
            AppendTensor(executor, reinterpret_cast<aclIntArray *>(arg->pointer), l);
            break;
        case OpArgType::OPARG_ACLTENSOR_LIST:
            AppendTensor(executor, reinterpret_cast<aclTensorList *>(arg->pointer), l);
            break;
        default:
            OP_LOGE(ACLNN_ERR_INNER, "invalid arg type %d.", static_cast<int>(arg.type));
            return;
    }
}

template<typename TensorList>
void CreateTensorList(aclOpExecutor *executor, OpArgList &t, TensorList &l)
{
    t.VisitByNoReturn([&]([[maybe_unused]] size_t idx, OpArg &arg) {
        CreateTensorListImpl(executor, arg, l);
    });
}

static inline uint8_t *Append1Byte(uint8_t *buf, uint8_t src)
{
    *buf = src;
    return buf + 1;
}

template<typename V>
void AppendAttrForKey(const V &value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < sizeof(value); ++i) {
        if (keyLen >= kAicpuKeyBufLen) {
            return;
        }
        ++keyLen;
        key = Append1Byte(key, *(reinterpret_cast<const uint8_t *> (&value) + i));
    }
}

static inline void AppendAttrForKey(const std::string &value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value.size(); ++i) {
        AppendAttrForKey(value[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(const std::string *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->size(); ++i) {
        AppendAttrForKey((*value)[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(std::string *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->size(); ++i) {
        AppendAttrForKey((*value)[i], key, keyLen);
    }
}

template<typename V>
static inline void AppendAttrForKey(const std::vector<V> &value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value.size(); ++i) {
        AppendAttrForKey(value[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(const aclIntArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(aclIntArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(const aclFloatArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(aclFloatArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(const aclBoolArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AppendAttrForKey(aclBoolArray *value, uint8_t *&key, size_t &keyLen)
{
    for (size_t i = 0U; i < value->Size(); ++i) {
        AppendAttrForKey(value->GetData()[i], key, keyLen);
    }
}

static inline void AddAicpuAttr(const aclIntArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<int64_t> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

static inline void AddAicpuAttr(aclIntArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<int64_t> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

static inline void AddAicpuAttr(const aclFloatArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<float> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

static inline void AddAicpuAttr(aclFloatArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<float> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

static inline void AddAicpuAttr(const aclBoolArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<bool> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

static inline void AddAicpuAttr(aclBoolArray *value, const std::string &attrName, AicpuAttrs &attrs)
{
    std::vector<bool> tmp;
    for (size_t i = 0U; i < value->Size(); i++) {
        tmp.emplace_back(value->GetData()[i]);
    }
    attrs[attrName] = AnyValue::CreateFrom(tmp);
}

template<typename V>
void AddAicpuAttr(const V &value, const std::string &attrName, AicpuAttrs &attrs)
{
    attrs[attrName] = AnyValue::CreateFrom(value);
}

inline uint64_t GetTid()
{
    thread_local static uint64_t tid = static_cast<uint64_t>(syscall(__NR_gettid));
    return tid;
}

class AicpuTask {
public:
    AicpuTask(const std::string &opType, const ge::UnknowShapeOpType unknownType)
        : opType_(opType), unknownType_(unknownType) {}

    virtual ~AicpuTask() = default;
    virtual aclnnStatus Init(const FVector<const aclTensor *> &inputs, const FVector<aclTensor *> &outputs,
                             const AicpuAttrs &attrs) = 0;
    virtual aclnnStatus Run(aclOpExecutor *executor, aclrtStream stream) = 0;

    aclnnStatus SetIoTensors(aclOpExecutor *executor, op::OpArgContext *args);

    friend class AicpuTaskSpace;
    void SetSpace(void *space)
    {
        space_ = space;
    }
    void SetVisit(bool visit);
protected:
    const std::string opType_;
    const ge::UnknowShapeOpType unknownType_;
    std::unique_ptr<AicpuArgsHandler> argsHandle_;
    std::unique_ptr<AicpuExtInfoHandler> extInfoHandle_;

    uint64_t launchId_ = 0U;
    uint64_t summaryItemId_ = 0U;
    void *space_ = nullptr;
    FVector<const aclTensor *> inputs_;
    FVector<aclTensor *> outputs_;
    // 长度可能不够，后续考虑长度可扩展
    uint8_t inputKey_[kAicpuKeyBufLen] = {};
    size_t keyLen_ = 0;
    bool isVisit_ = false;
    uint64_t deviceExtMemSize_ = 0;
    uint64_t deviceCacheOffset_ = 0;
    aclrtStream stream_{nullptr};
};

class AicpuTfTask : public AicpuTask {
public:
    AicpuTfTask(const std::string &opType, const ge::UnknowShapeOpType unknownType)
        : AicpuTask(opType, unknownType) {}
    aclnnStatus Init(const FVector<const aclTensor *> &inputs, const FVector<aclTensor *> &outputs,
                     const AicpuAttrs &attrs);
    aclnnStatus Run(aclOpExecutor *executor, aclrtStream stream);
private:
    aclnnStatus LaunchKernelByNewInterface(aclrtStream stream);
    aclrtBinHandle tfBinHandle_ = nullptr;
    aclrtFuncHandle funcHandle_ = nullptr;
    bool useNewLaunchInterface_ = false;
};

class AicpuCCTask : public AicpuTask {
public:
    AicpuCCTask(const std::string &opType, const ge::UnknowShapeOpType unknownType)
        : AicpuTask(opType, unknownType) {}
    aclnnStatus Init(const FVector<const aclTensor *> &inputs, const FVector<aclTensor *> &outputs,
                     const AicpuAttrs &attrs);
    aclnnStatus Run(aclOpExecutor *executor, aclrtStream stream);
private:
    aclnnStatus GetKernelNameAndSoName(std::string &kernelSoName);
    aclnnStatus LaunchKernelByNewInterface(aclrtStream stream);
    aclrtBinHandle aicpuBinHandle_ = nullptr;
    aclrtFuncHandle funcHandle_ = nullptr;
    bool useNewLaunchInterface_ = false;
    bool isCustomTask_ = false;
    std::string functionName_ = kDefaultFunctionName;
};

class AicpuTaskSpace {
public:
    // 需要设置第几类动态shape算子，tf or 自研，默认设置为自研第一类算子
    AicpuTaskSpace(const std::string &opType,
                   const ge::UnknowShapeOpType unknownType = ge::DEPEND_IN_SHAPE,
                   const bool isTf = false)
        : opType_(opType), unknownType_(unknownType), isTf_(isTf) {}

    AicpuTask *FindTask(aclOpExecutor *executor, op::OpArgContext *args,
                        const FVector<const aclTensor *> &inputs);
    AicpuTask *GetOrCreateTask(aclOpExecutor *executor, const FVector<std::string> &attrNames,
                               op::OpArgContext *args);
    void SetRef(const size_t index, const bool isInput = true);
    bool IsRef(const size_t index, const bool isInput = true) const;
    uint64_t CalcHostInputDataSize(const FVector<const aclTensor *> &inputs, size_t alignBytes) const;
    uint64_t CalcDeviceCacheSize(const FVector<const aclTensor *> &inputs,
                                 std::unique_ptr<AicpuTask> &aicpuTask) const;
    void Clear()
    {
        hashMap_.clear();
    }
    friend class AicpuTask;
private:
    static constexpr uint64_t kHashSeed = 0x9e3779b9U;
    static size_t GenHashBinary(const uint8_t *addr, uint32_t len);
    size_t GenTaskKey(uint8_t inputKey[], size_t &keyLen, op::OpArgContext *args,
                      const FVector<const aclTensor *> &inputs) const;

    const std::string opType_;
    const ge::UnknowShapeOpType unknownType_;
    const bool isTf_;
    bool hasInit_ = false;
    std::set<size_t> inputRefIndexes_;
    std::set<size_t> outputRefIndexes_;
    std::mutex mutex_;
    using HashMap = std::unordered_map<size_t, std::vector<std::unique_ptr<AicpuTask>>>;
    HashMap hashMap_;
};

void aclnnAicpuFinalize();
#define OP_ATTR_NAMES ::op::FVector<std::string>

aclnnStatus CreatAicpuKernelLauncher(uint32_t opType, op::internal::AicpuTaskSpace &space,
                                aclOpExecutor *executor, const FVector<std::string> &attrNames,
                                op::OpArgContext *args);
// log profiling
#define ADD_TO_LAUNCHER_LIST_AICPU(KERNEL_NAME, attrNames, opArgs...) \
    ({                                                                \
        OP_LOGI("mock ADD_TO_LAUNCHER_LIST_AICPU for AICPU UT");      \
        ACLNN_SUCCESS;                                                \
    })
} // namespace internal
} // namespace op
#endif // OP_API_COMMON_INC_OPDEV_AICPU_AICPU_TASK_H_
