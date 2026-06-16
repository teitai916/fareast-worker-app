package com.fareast.worker.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    private String phone;

    private String password;

    private String verificationCode;

    private String name;

    private String chineseName;

    private String englishName;

    /** 注册角色，可选值：WORKER / CONTRACTOR，默认 WORKER */
    private String role;

    /** 判头注册时选择所属公司ID */
    private Long companyId;
}
