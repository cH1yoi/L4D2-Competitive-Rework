<?php
$demos_dir = './demos';

if (isset($_GET['file'])) {
    $relative_path = str_replace('..', '', $_GET['file']); // 安全检查
    $filepath = $demos_dir . '/' . $relative_path;
    
    if (file_exists($filepath) && is_file($filepath)) {
        header('Content-Type: application/zip');
        header('Content-Disposition: attachment; filename="' . basename($filepath) . '"');
        header('Content-Length: ' . filesize($filepath));
        readfile($filepath);
        exit;
    }
}

header('Location: index.php');