/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

#include <filesystem>
#include <gtest/gtest.h>
#include "base/registry/op_impl_space_registry_v2.h"

using namespace std;

class OpKernelUtEnvironment : public testing::Environment {
public:
    OpKernelUtEnvironment(char** argv) : argv_(argv)
    {}
    virtual void SetUp()
    {
        cout << "Global Environment SetpUp." << endl;

        /* load libmath_op_kernel_ut_${socversion}_ut.so for init tiling funcs and infershape funcs */

        std::filesystem::path currDir = argv_[0];
        if (currDir.is_relative()) {
            currDir = std::filesystem::weakly_canonical(std::filesystem::current_path() / currDir);
        } else {
            currDir = std::filesystem::canonical(currDir);
        }
        string opKernelTilingSoPath = currDir.parent_path().string() + string("/libmath_op_kernel_ut_tiling.so");

        gert::OppSoDesc oppSoDesc({ge::AscendString(opKernelTilingSoPath.c_str())}, "math_op_kernel_ut_so");
        shared_ptr<gert::OpImplSpaceRegistryV2> opImplSpaceRegistryV2 = make_shared<gert::OpImplSpaceRegistryV2>();
        if (opImplSpaceRegistryV2->AddSoToRegistry(oppSoDesc) == ge::GRAPH_FAILED) {
            cout << "add so to registry failed." << endl;
            return;
        }

        gert::DefaultOpImplSpaceRegistryV2::GetInstance().SetSpaceRegistry(opImplSpaceRegistryV2);
    }

    virtual void TearDown()
    {
        cout << "Global Environment TearDown" << endl;
    }

private:
    char** argv_;
};

int main(int argc, char** argv)
{
    testing::InitGoogleTest(&argc, argv);
    testing::AddGlobalTestEnvironment(new OpKernelUtEnvironment(argv));
    return RUN_ALL_TESTS();
}
