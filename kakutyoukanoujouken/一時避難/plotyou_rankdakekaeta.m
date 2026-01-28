%% plot_8plots_standalone.m
% 解析結果から8つのプロットを生成（前のコードベース）
clear; clc; close all;

% ===== 結果フォルダを指定 =====
out_dir = 'results_20260119_145358';  % ← 実際のフォルダ名に変更
load(fullfile(out_dir, 'zeq_extended_search.mat'), 'res');

fprintf('========================================\n');
fprintf(' 8-Plot Generation (Enhanced Version)\n');
fprintf('========================================\n\n');

% ===== 収束判定 =====
z_min_required = 0.5;  % [mm] 最低限の初期たわみ
cv = [res.converged];
r = res(cv);

if isempty(r)
    fprintf('[ERROR] No converged results found.\n');
    return;
end

fprintf('Converged: %d / %d designs (%.1f%%)\n\n', ...
    length(r), length(res), 100*length(r)/length(res));

% ===== プロット用サンプリング（1000点まで） =====
n_all = length(r);
if n_all > 1000
    idx_sample = randperm(n_all, 1000);
    r_plot = r(idx_sample);
    fprintf('Plotting %d / %d points (random sampling for speed)\n', 1000, n_all);
else
    r_plot = r;
    fprintf('Plotting all %d points\n', n_all);
end

% プロット用データ（サンプリング済み）
za = [r_plot.z_eq_mm]; 
aa = [r_plot.A_z_mm]; 
fa = [r_plot.f_res_Hz]; 
xp = [r_plot.x_push_m]*1000; 
ws = [r_plot.w1_stiff_m]*1000;
wm = [r_plot.w1_mass_m]*1000; 
Ls = [r_plot.L_m]*1000;
ratio_plot = aa ./ za;

% ===== Top20抽出（全データからratio降順） =====
za_all = [r.z_eq_mm]; 
aa_all = [r.A_z_mm];
ratio_all = aa_all ./ za_all;
[~, ix] = sort(ratio_all, 'descend');  % A_z/z_eq 比で降順

top_designs = r(ix(1:min(20, length(r))));
ratio_top = [top_designs.A_z_mm] ./ [top_designs.z_eq_mm];

% 統計情報
n_snap = sum(ratio_all > 1.0);
n_total = length(ratio_all);

fprintf('\n========================================\n');
fprintf(' Creating 8-Plot Figure...\n');
fprintf('========================================\n');

% ===== 8グラフのプロット =====
fig = figure('Color','w','Position',[50 50 1800 1000]);

% (1) Top 20: A_z/z_eq ratio（ratio順にソート済み）
subplot(2,4,1);
bar(ratio_top, 'FaceColor', [0.2 0.5 0.8], 'EdgeColor', 'k'); 
hold on;
yline(1.0, 'r--', 'LineWidth', 2.5);
xlabel('Rank', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z / z_{eq}', 'FontSize', 11, 'FontWeight', 'bold');
title('Top 20: Snapthrough Indicator', 'FontSize', 12, 'FontWeight', 'bold'); 
legend('Ratio', 'Threshold=1.0', 'Location','northeast');
grid on;
ylim([0 max(ratio_top)*1.15]);

% (2) Distribution of A_z/z_eq ratio
subplot(2,4,2);
histogram(ratio_plot, 50, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k'); 
hold on;
xline(1.0, 'r--', 'LineWidth', 2.5, 'Label', 'Threshold=1.0');
xlabel('A_z / z_{eq}', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('Count', 'FontSize', 11, 'FontWeight', 'bold');
title(sprintf('Distribution (%.1f%% > 1.0)', 100*n_snap/n_total), ...
    'FontSize', 12, 'FontWeight', 'bold');
grid on;

% (3) Design space map (xpush vs zeq + 理論曲線)
subplot(2,4,3);
scatter(xp, za, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.7);
colorbar; caxis([0 2]); colormap(gca, jet);
hold on; 
x_theory = linspace(min(xp), max(xp), 100);
z_theory = sqrt(2*x_theory/0.2794);
plot(x_theory, z_theory, 'k--', 'LineWidth', 2);
xlabel('x_{push} [mm]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('z_{eq} [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('Design Space (color=A_z/z_{eq})', 'FontSize', 12, 'FontWeight', 'bold');
legend('Data', 'Theory z_{eq}', 'Location','northwest');
grid on;

% (4) x_push vs A_z
subplot(2,4,4);
scatter(xp, aa, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.6);
colorbar; caxis([0 2]);
xlabel('x_{push} [mm]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('x_{push} effect', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% (5) w1_stiff vs A_z (log scale)
subplot(2,4,5);
scatter(ws, aa, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.6);
set(gca, 'XScale', 'log');
colorbar; caxis([0 2]);
xlabel('w_{1,stiff} [mm]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('w_{1,stiff} effect (log scale)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% (6) w1_mass vs A_z
subplot(2,4,6);
scatter(wm, aa, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.6);
colorbar; caxis([0 2]);
xlabel('w_{1,mass} [mm]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('w_{1,mass} effect', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% (7) L vs A_z
subplot(2,4,7);
scatter(Ls, aa, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.6);
colorbar; caxis([0 2]);
xlabel('L [mm]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('L (span) effect', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% (8) f_res vs A_z
subplot(2,4,8);
scatter(fa, aa, 30, ratio_plot, 'filled', 'MarkerFaceAlpha', 0.6);
colorbar; caxis([0 2]);
xlabel('f_{res} [Hz]', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('A_z [mm]', 'FontSize', 11, 'FontWeight', 'bold');
title('Resonance frequency effect', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% ===== 保存 =====
fig_file = fullfile(out_dir, 'results_8plots_enhanced.png');
try
    exportgraphics(fig, fig_file, 'Resolution', 300);
    fprintf('[SAVED] %s\n', fig_file);
catch ME
    fprintf('[WARNING] exportgraphics failed: %s\n', ME.message);
    try
        print(fig, fig_file, '-dpng', '-r300');
        fprintf('[SAVED] %s (via print)\n', fig_file);
    catch ME2
        fprintf('[ERROR] Could not save figure automatically.\n');
    end
end

% FIG形式も保存
saveas(fig, fullfile(out_dir, 'results_8plots_enhanced.fig'));
fprintf('[SAVED] %s/results_8plots_enhanced.fig\n', out_dir);

% ===== コンソール出力（ratio順Top20） =====
fprintf('\n========================================\n');
fprintf(' TOP 20 (Sorted by A_z/z_eq ratio)\n');
fprintf('========================================\n');
fprintf('Rank | x_push | w_stiff | w_mass | L    | A_z    | z_eq   | f_res | Az/zeq\n');
fprintf('-----|--------|---------|--------|------|--------|--------|-------|-------\n');
for i = 1:length(top_designs)
    fprintf('%4d | %6.3f | %7.2f | %6.1f | %4.1f | %6.3f | %6.3f | %6.1f | %.3f\n', ...
        i, top_designs(i).x_push_m*1000, top_designs(i).w1_stiff_m*1000, ...
        top_designs(i).w1_mass_m*1000, top_designs(i).L_m*1000, ...
        top_designs(i).A_z_mm, top_designs(i).z_eq_mm, ...
        top_designs(i).f_res_Hz, ratio_top(i));
end
fprintf('========================================\n\n');

% ===== Best design summary =====
best = top_designs(1);
fprintf('========================================\n');
fprintf(' BEST DESIGN (Rank 1)\n');
fprintf('========================================\n');
fprintf('  x_push   = %.3f mm\n', best.x_push_m*1000);
fprintf('  w1_stiff = %.2f mm\n', best.w1_stiff_m*1000);
fprintf('  w1_mass  = %.1f mm\n', best.w1_mass_m*1000);
fprintf('  L        = %.1f mm\n', best.L_m*1000);
fprintf('  A_z      = %.3f mm\n', best.A_z_mm);
fprintf('  z_eq     = %.3f mm\n', best.z_eq_mm);
fprintf('  f_res    = %.1f Hz\n', best.f_res_Hz);
fprintf('  A_z/z_eq = %.3f  <-- MAX RATIO\n', ratio_top(1));
fprintf('========================================\n\n');

if ratio_top(1) > 1.5
    fprintf('>>> VERY HIGH snapthrough potential (A_z/z_eq > 1.5)\n\n');
elseif ratio_top(1) > 1.0
    fprintf('>>> HIGH snapthrough potential (A_z/z_eq > 1.0)\n\n');
elseif ratio_top(1) > 0.5
    fprintf('>>> MODERATE snapthrough potential (0.5 < A_z/z_eq < 1.0)\n\n');
else
    fprintf('>>> LOW snapthrough potential (A_z/z_eq < 0.5)\n\n');
end

fprintf('========================================\n');
fprintf(' STATISTICS\n');
fprintf('========================================\n');
fprintf('  Designs with A_z/z_eq > 1.0: %d / %d (%.1f%%)\n', ...
    n_snap, n_total, 100*n_snap/n_total);
fprintf('  Max A_z/z_eq ratio: %.3f (Rank 1)\n', max(ratio_all));
fprintf('  Mean A_z/z_eq ratio: %.3f\n', mean(ratio_all));
fprintf('  Std A_z/z_eq ratio: %.3f\n', std(ratio_all));
fprintf('========================================\n');
