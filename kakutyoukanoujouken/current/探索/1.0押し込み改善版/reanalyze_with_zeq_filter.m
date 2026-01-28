% =========================================================================
% 既存結果の再解析：zeq下限フィルタを適用
% =========================================================================
clear; clc; close all;

% 1. 既存結果を読み込み
fprintf('Loading existing results...\n');
load('results_20260119_145358\zeq_extended_search.mat');

% 2. フィルタリング条件
z_min_required = 0.5;  % [mm] 最低限の初期たわみ

fprintf('\n========================================\n');
fprintf('   Re-analysis with z_eq filter\n');
fprintf('========================================\n');

% 3. 収束したものを抽出
cv = [res.converged];
r = res(cv);
za_all = [r.z_eq_mm]; 
aa_all = [r.A_z_mm];

fprintf('Original converged designs: %d\n', length(r));
fprintf('z_eq range: %.3f ~ %.3f mm\n', min(za_all), max(za_all));

% 4. ★追加フィルタ★
z_valid = (za_all >= z_min_required);

r_filtered = r(z_valid);
za_filtered = za_all(z_valid);
aa_filtered = aa_all(z_valid);

fprintf('\nAfter z_eq >= %.1f mm filter:\n', z_min_required);
fprintf('  Remaining designs: %d\n', length(r_filtered));
fprintf('  Filtered out: %d\n', sum(~z_valid));

% 5. ratio計算とソート
ratio_filtered = aa_filtered ./ za_filtered;
[~, ix] = sort(ratio_filtered, 'descend');

n_top = min(20, length(r_filtered));
top_designs_filtered = r_filtered(ix(1:n_top));

fprintf('\n--- Top %d designs (filtered) ---\n', n_top);
fprintf('Rank | z_eq [mm] | A_z [mm] | Ratio | xp [mm] | ws [mm] | wm [mm] | L [mm]\n');
fprintf('-----|-----------|----------|-------|---------|---------|---------|--------\n');
for i = 1:n_top
    d = top_designs_filtered(i);
    fprintf('%4d | %9.3f | %8.3f | %5.2f | %7.3f | %7.2f | %7.1f | %6.1f\n', ...
        i, d.z_eq_mm, d.A_z_mm, d.A_z_mm/d.z_eq_mm, ...
        d.x_push_m*1000, d.w1_stiff_m*1000, d.w1_mass_m*1000, d.L_m*1000);
end
fprintf('========================================\n\n');

% 6. 比較プロット
figure('Color','w','Position',[100 100 1400 500]);

% 左：フィルタ前
subplot(1,2,1);
ratio_all = aa_all ./ za_all;
scatter(za_all, ratio_all, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
yline(1.0, 'r--', 'LineWidth', 2, 'Label', 'Ratio=1.0');
xline(z_min_required, 'g--', 'LineWidth', 2, 'Label', sprintf('z_{eq}=%.1fmm', z_min_required));
hold off;
xlabel('z_{eq} [mm]'); ylabel('A_z / z_{eq}');
title(sprintf('Before filter (N=%d)', length(r)));
grid on; xlim([0 max(za_all)*1.1]); ylim([0 max(ratio_all)*1.1]);

% 右：フィルタ後
subplot(1,2,2);
scatter(za_filtered, ratio_filtered, 50, ratio_filtered, 'filled');
hold on;
yline(1.0, 'r--', 'LineWidth', 2);
% Top 20をハイライト
for i = 1:min(10, n_top)
    d = top_designs_filtered(i);
    plot(d.z_eq_mm, d.A_z_mm/d.z_eq_mm, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    text(d.z_eq_mm, d.A_z_mm/d.z_eq_mm, sprintf(' %d', i), 'FontSize', 10);
end
hold off;
xlabel('z_{eq} [mm]'); ylabel('A_z / z_{eq}');
title(sprintf('After filter (N=%d)', length(r_filtered)));
colorbar; grid on;
xlim([z_min_required*0.9 max(za_filtered)*1.1]); ylim([0 max(ratio_filtered)*1.1]);

sgtitle('Design Space: Before/After z_{eq} Filter', 'FontSize', 14, 'FontWeight', 'bold');

% 7. 保存
save('results_20260119_145358\top_designs_filtered.mat', ...
    'top_designs_filtered', 'z_min_required', 'fx', 'cfg');
fprintf('[SAVED] top_designs_filtered.mat\n');

% 8. （オプション）そのまま検証に進む場合
fprintf('\n>>> To verify snapthrough:\n');
fprintf('    snap_summary = verify_snapthrough_top20(top_designs_filtered, fx, cfg, pwd);\n\n');
