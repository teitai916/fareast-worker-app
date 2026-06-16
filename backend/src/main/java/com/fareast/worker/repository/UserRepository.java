package com.fareast.worker.repository;

import com.fareast.worker.model.entity.User;
import com.fareast.worker.model.enums.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByPhone(String phone);

    boolean existsByPhone(String phone);

    List<User> findByRole(UserRole role);

    List<User> findByCompanyIdAndRole(Long companyId, UserRole role);
}
