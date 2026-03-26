/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */
#include <array>
#include <vector>
#include "gtest/gtest.h"

#include "../../../../op_host/op_api/aclnn_segsum.h"

#include "op_api_ut_common/op_api_ut.h"
#include "op_api_ut_common/tensor_desc.h"

using namespace op;
using namespace std;

class l2_segsum_test : public testing::Test
{
protected:
    static void SetUpTestCase()
    {
        cout << "segsum_test_test SetUp" << endl;
    }

    static void TearDownTestCase()
    {
        cout << "segsum_test_test TearDown" << endl;
    }
};

TEST_F(l2_segsum_test, ascend910B2_case_3D_valid)
{
    auto self_desc = TensorDesc({1, 2, 3}, ACL_FLOAT, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 3}, ACL_FLOAT, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACL_SUCCESS);
}

TEST_F(l2_segsum_test, ascend910B2_case_4D_valid)
{
    auto self_desc = TensorDesc({1, 2, 3, 2}, ACL_FLOAT, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 2, 2}, ACL_FLOAT, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACL_SUCCESS);
}

TEST_F(l2_segsum_test, ascend910B2_case_2D_invalid)
{
    auto self_desc = TensorDesc({1, 2}, ACL_FLOAT, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 2}, ACL_FLOAT, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_5D_invalid)
{
    auto self_desc = TensorDesc({1, 1, 2, 2, 2}, ACL_FLOAT, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 1, 2, 2, 2, 2}, ACL_FLOAT, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_half_valid)
{
    auto self_desc = TensorDesc({1, 2, 3, 2}, ACL_FLOAT16, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 2, 2}, ACL_FLOAT16, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACL_SUCCESS);
}

TEST_F(l2_segsum_test, ascend910B2_case_bfloat16_valid)
{
    auto self_desc = TensorDesc({1, 2, 3, 2}, ACL_BF16, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 2, 2}, ACL_BF16, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACL_SUCCESS);
}

TEST_F(l2_segsum_test, ascend910B2_case_shape_invalid_1)
{
    auto self_desc = TensorDesc({1, 2, 3, 2}, ACL_BF16, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 3, 3, 2, 2}, ACL_BF16, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_shape_invalid_2)
{
    auto self_desc = TensorDesc({1, 2, 3, 2}, ACL_BF16, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 2, 3}, ACL_BF16, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_shape_invalid_3)
{
    auto self_desc = TensorDesc({1, 2, 2, 2}, ACL_BF16, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 2, 2}, ACL_BF16, ACL_FORMAT_ND);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_format_invalid_1)
{
    auto self_desc = TensorDesc({1, 2, 3}, ACL_FLOAT, ACL_FORMAT_NCHW);
    auto out_desc = TensorDesc({1, 2, 3, 3}, ACL_FLOAT, ACL_FORMAT_NCHW);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}

TEST_F(l2_segsum_test, ascend910B2_case_format_invalid_2)
{
    auto self_desc = TensorDesc({1, 2, 3}, ACL_FLOAT, ACL_FORMAT_ND);
    auto out_desc = TensorDesc({1, 2, 3, 3}, ACL_FLOAT, ACL_FORMAT_NCHW);

    auto ut = OP_API_UT(aclnnExpSegsum, INPUT(self_desc), OUTPUT(out_desc));

    uint64_t workspace_size = 0;
    aclnnStatus aclRet = ut.TestGetWorkspaceSize(&workspace_size);
    EXPECT_EQ(aclRet, ACLNN_ERR_PARAM_INVALID);
}