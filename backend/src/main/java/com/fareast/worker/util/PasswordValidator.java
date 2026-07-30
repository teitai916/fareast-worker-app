package com.fareast.worker.util;

import com.fareast.worker.exception.BusinessException;
import org.springframework.stereotype.Component;

import java.util.Set;

/**
 * 6位數字密碼複雜度校驗工具。
 *
 * 在保持「6位純數字」的前提下，通過攔截常見弱密碼模式提升有效複雜度：
 * 1. 長度與純數字約束
 * 2. 全同數字（000000~999999）
 * 3. 等差序列（012345 / 123456 / 654321 ...）
 * 4. 常見弱密碼黑名單（標準檔）
 * 5. 與個人信息關聯：手機號後6位、出生日期後6位
 */
@Component
public class PasswordValidator {

    /** 標準弱密碼黑名單（高頻6位弱密碼） */
    private static final Set<String> WEAK_PASSWORDS = Set.of(
            "123456", "111111", "000000", "123123", "112233", "123321",
            "121212", "654321", "123454", "222222", "333333", "444444"
    );

    /**
     * 校驗密碼複雜度。
     *
     * @param password  明文密碼（必須為6位純數字）
     * @param phone     用戶手機號（可空，用於「後6位」關聯比對）
     * @param birthDate 出生日期（可空，格式 yyyy-MM-dd 或 yyyyMMdd，用於生日關聯比對）
     */
    public void validate(String password, String phone, String birthDate) {
        if (password == null || password.length() < 6) {
            throw new BusinessException(400, "密碼長度至少為6位");
        }
        if (!password.chars().allMatch(Character::isDigit)) {
            throw new BusinessException(400, "密碼必須為6位純數字");
        }
        if (password.length() > 32) {
            throw new BusinessException(400, "密碼長度不能超過32位");
        }

        // 全同數字：000000 / 111111 / ...
        if (isAllSame(password)) {
            throw new BusinessException(400, "密碼過於簡單，請勿使用重複數字");
        }

        // 等差序列：012345 / 123456 / 654321 / 987654 ...
        if (isArithmeticSequence(password)) {
            throw new BusinessException(400, "密碼過於簡單，請勿使用連續數字");
        }

        // 常見弱密碼黑名單
        if (WEAK_PASSWORDS.contains(password)) {
            throw new BusinessException(400, "該密碼過於常見，請更換其他密碼");
        }

        // 與手機號後6位相同
        if (phone != null && phone.length() >= 6) {
            String last6 = phone.substring(phone.length() - 6);
            if (password.equals(last6)) {
                throw new BusinessException(400, "密碼不能與手機號後6位相同");
            }
        }

        // 與出生日期後6位相同（MMDDYY 或 YYMMDD）
        if (birthDate != null && !birthDate.isBlank()) {
            String digits = birthDate.replaceAll("\\D", "");
            if (digits.length() == 8) {
                String mmddyy = digits.substring(4, 6) + digits.substring(6, 8) + digits.substring(2, 4);
                String yymmdd = digits.substring(2, 4) + digits.substring(4, 6) + digits.substring(6, 8);
                if (password.equals(mmddyy) || password.equals(yymmdd)) {
                    throw new BusinessException(400, "密碼不能與出生日期後6位相同");
                }
            } else if (digits.length() == 6) {
                if (password.equals(digits)) {
                    throw new BusinessException(400, "密碼不能與出生日期後6位相同");
                }
            }
        }
    }

    /** 是否全部為同一個數字 */
    private boolean isAllSame(String pwd) {
        for (int i = 1; i < pwd.length(); i++) {
            if (pwd.charAt(i) != pwd.charAt(0)) {
                return false;
            }
        }
        return true;
    }

    /** 是否為等差數字序列（步長可為正/負，如 123456 / 654321 / 024680 不屬此類） */
    private boolean isArithmeticSequence(String pwd) {
        int step = pwd.charAt(1) - pwd.charAt(0);
        for (int i = 2; i < pwd.length(); i++) {
            if (pwd.charAt(i) - pwd.charAt(i - 1) != step) {
                return false;
            }
        }
        return true;
    }
}
