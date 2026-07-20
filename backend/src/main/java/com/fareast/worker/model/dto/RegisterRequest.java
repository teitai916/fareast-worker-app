package com.fareast.worker.model.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^\\d{8,11}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 32, message = "密码长度为6-32位")
    private String password;

    @NotBlank(message = "验证码不能为空")
    @Size(min = 6, max = 6, message = "验证码为6位数字")
    private String verificationCode;

    private String name;

    @Size(max = 50, message = "中文姓名不超过50个字符")
    private String chineseName;

    @Size(max = 50, message = "英文姓名不超过50个字符")
    private String englishName;

    /** 注册角色，可选值：WORKER / CONTRACTOR，默认 WORKER */
    @Pattern(regexp = "^(WORKER|CONTRACTOR)$", message = "角色值无效")
    private String role;

    /** 判头注册时选择所属公司ID */
    private Long companyId;

    /** 手机国际区号，如 +852、+86 */
    private String countryCode;

    /** 工人出生日期（格式：yyyy-MM-dd，工人注册时必填） */
    @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$", message = "出生日期格式不正确")
    private String birthDate;
}
