package com.example.taskapi.controller;

import com.example.taskapi.service.FileStorageService;
import org.springframework.context.annotation.Profile;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/files")
@Profile("local")
public class FileController {

    private final FileStorageService fileStorageService;

    public FileController(FileStorageService fileStorageService) {
        this.fileStorageService = fileStorageService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> listFiles(@RequestParam Long taskId) {
        List<Map<String, Object>> files = fileStorageService.listFiles(taskId);
        return ResponseEntity.ok(Map.of(
                "files", files,
                "taskId", taskId
        ));
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> uploadFile(
            @RequestParam Long taskId,
            @RequestParam("file") MultipartFile file) {
        String key = fileStorageService.storeFile(taskId, file);
        return ResponseEntity.ok(Map.of(
                "message", "File uploaded successfully",
                "key", key,
                "fileName", file.getOriginalFilename(),
                "taskId", taskId
        ));
    }

    @GetMapping("/download")
    public ResponseEntity<Resource> downloadFile(
            @RequestParam Long taskId,
            @RequestParam String fileName) {
        Resource resource = fileStorageService.loadFileAsResource(taskId, fileName);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + fileName + "\"")
                .body(resource);
    }

    @DeleteMapping
    public ResponseEntity<Map<String, Object>> deleteFile(@RequestBody Map<String, Object> request) {
        Long taskId = Long.valueOf(request.get("taskId").toString());
        String fileName = request.get("fileName").toString();

        fileStorageService.deleteFile(taskId, fileName);
        return ResponseEntity.ok(Map.of(
                "message", "File deleted successfully",
                "fileName", fileName,
                "taskId", taskId
        ));
    }
}
