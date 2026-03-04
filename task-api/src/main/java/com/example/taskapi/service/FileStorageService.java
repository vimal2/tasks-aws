package com.example.taskapi.service;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Service
@Profile("local")
public class FileStorageService {

    @Value("${file.storage.location:./uploads}")
    private String storageLocation;

    private Path rootLocation;

    @PostConstruct
    public void init() {
        rootLocation = Paths.get(storageLocation).toAbsolutePath().normalize();
        try {
            Files.createDirectories(rootLocation);
            System.out.println("File storage initialized at: " + rootLocation);
        } catch (IOException e) {
            throw new RuntimeException("Could not create upload directory: " + rootLocation, e);
        }
    }

    public String storeFile(Long taskId, MultipartFile file) {
        String originalFilename = file.getOriginalFilename();

        if (originalFilename == null || originalFilename.isBlank()) {
            throw new RuntimeException("File name is empty");
        }

        // Extract just the filename, handling both Windows (\) and Unix (/) paths
        String fileName = extractFileName(originalFilename);

        try {
            if (fileName.contains("..")) {
                throw new RuntimeException("Invalid file path: " + fileName);
            }

            Path taskDir = rootLocation.resolve("tasks").resolve(String.valueOf(taskId));
            Files.createDirectories(taskDir);

            Path targetLocation = taskDir.resolve(fileName);
            Files.copy(file.getInputStream(), targetLocation, StandardCopyOption.REPLACE_EXISTING);

            System.out.println("File stored at: " + targetLocation);
            return "tasks/" + taskId + "/" + fileName;
        } catch (IOException e) {
            throw new RuntimeException("Could not store file " + fileName + ": " + e.getMessage(), e);
        }
    }

    private String extractFileName(String fullPath) {
        if (fullPath == null) {
            return null;
        }
        // Handle Windows paths (backslash)
        int lastBackslash = fullPath.lastIndexOf('\\');
        // Handle Unix paths (forward slash)
        int lastSlash = fullPath.lastIndexOf('/');

        int lastSeparator = Math.max(lastBackslash, lastSlash);

        if (lastSeparator >= 0) {
            return fullPath.substring(lastSeparator + 1);
        }
        return fullPath;
    }

    public Resource loadFileAsResource(Long taskId, String fileName) {
        try {
            Path filePath = rootLocation.resolve("tasks")
                    .resolve(String.valueOf(taskId))
                    .resolve(fileName)
                    .normalize();
            Resource resource = new UrlResource(filePath.toUri());

            if (resource.exists() && resource.isReadable()) {
                return resource;
            } else {
                throw new RuntimeException("File not found: " + fileName);
            }
        } catch (MalformedURLException e) {
            throw new RuntimeException("File not found: " + fileName, e);
        }
    }

    public void deleteFile(Long taskId, String fileName) {
        try {
            Path filePath = rootLocation.resolve("tasks")
                    .resolve(String.valueOf(taskId))
                    .resolve(fileName)
                    .normalize();
            Files.deleteIfExists(filePath);
        } catch (IOException e) {
            throw new RuntimeException("Could not delete file: " + fileName, e);
        }
    }

    public List<Map<String, Object>> listFiles(Long taskId) {
        try {
            Path taskDir = rootLocation.resolve("tasks").resolve(String.valueOf(taskId));

            if (!Files.exists(taskDir)) {
                return List.of();
            }

            try (Stream<Path> files = Files.list(taskDir)) {
                return files
                        .filter(Files::isRegularFile)
                        .map(path -> {
                            try {
                                return Map.<String, Object>of(
                                        "key", "tasks/" + taskId + "/" + path.getFileName().toString(),
                                        "name", path.getFileName().toString(),
                                        "size", Files.size(path),
                                        "lastModified", Files.getLastModifiedTime(path).toInstant().toString(),
                                        "taskId", taskId
                                );
                            } catch (IOException e) {
                                return Map.<String, Object>of(
                                        "key", "tasks/" + taskId + "/" + path.getFileName().toString(),
                                        "name", path.getFileName().toString(),
                                        "size", 0L,
                                        "lastModified", Instant.now().toString(),
                                        "taskId", taskId
                                );
                            }
                        })
                        .collect(Collectors.toList());
            }
        } catch (IOException e) {
            throw new RuntimeException("Could not list files for task: " + taskId, e);
        }
    }
}
