% 結果を読み込んで再プロット
load('results_20260119_145358\zeq_extended_search.mat');

% 改良版プロット関数を単独で実行
[top_designs, fig_handle] = plot_res_enhanced_safe(res, 'results_20260119_145358');

% ========== plot_res_enhanced_safe関数（コピペ） ==========
function [top_designs, fig_handle] = plot_res_enhanced_safe(res, out_dir)
    cv = [res.converged]; r = res(cv);
    if isempty(r), fprintf('No converged results\n'); top_designs = []; fig_handle = []; return; end
    
    % データ点を1000点に制限（高速化）
    n_all = length(r);
    if n_all > 1000
        idx_sample = randperm(n_all, 1000);
        r_plot = r(idx_sample);
        fprintf('Plotting %d / %d points for speed\n', 1000, n_all);
    else
        r_plot = r;
    end
    
    za = [r_plot.z_eq_mm]; aa = [r_plot.A_z_mm]; fa = [r_plot.f_res_Hz]; 
    xp = [r_plot.x_push_m]*1000; ws = [r_plot.w1_stiff_m]*1000;
    wm = [r_plot.w1_mass_m]*1000; Ls = [r_plot.L_m]*1000;
    ratio_all = aa ./ za;
    
    % Top 20は全データから抽出
    [~, ix] = sort([r.A_z_mm], 'descend');
    top_designs = r(ix(1:min(20, length(r))));
    ratio_top = [top_designs.A_z_mm] ./ [top_designs.z_eq_mm];
    
    % ========== 8 subplots（同じ） ==========
    fig_handle = figure('Color','w','Position',[50 50 1800 1000]);
    
    subplot(2,4,1);
    bar(ratio_top); hold on;
    yline(1.0, 'r--', 'LineWidth', 2);
    xlabel('Rank'); ylabel('A_z / z_{eq}');
    title('Top 20: Snapthrough Indicator'); 
    legend('Ratio', 'Threshold=1.0', 'Location','northeast');
    grid on;
    
    subplot(2,4,2);
    histogram(ratio_all, 40); hold on;
    xline(1.0, 'r--', 'LineWidth', 2);
    xlabel('A_z / z_{eq}'); ylabel('Count');
    title('Distribution (snapthrough if >1.0)');
    n_snap = sum(ratio_all > 1.0);
    n_total = length(ratio_all);
    text(1.5, max(ylim)*0.8, sprintf('%.1f%% > 1.0', 100*n_snap/n_total), ...
        'FontSize', 10, 'FontWeight', 'bold');
    grid on;
    
    subplot(2,4,3);
    scatter(xp, za, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.7);
    colorbar; caxis([0 2]); colormap(gca, jet);
    hold on; 
    x_theory = linspace(0, 1, 100);
    z_theory = sqrt(2*x_theory/0.2794);
    plot(x_theory, z_theory, 'k--', 'LineWidth', 1.5);
    xlabel('x_{push} [mm]'); ylabel('z_{eq} [mm]');
    title('Design Space (color=A_z/z_{eq})');
    legend('Data', 'Theory z_{eq}', 'Location','northwest');
    grid on;
    
    subplot(2,4,4);
    scatter(xp, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('x_{push} [mm]'); ylabel('A_z [mm]');
    title('x_{push} effect'); grid on;
    
    subplot(2,4,5);
    scatter(ws, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    set(gca, 'XScale', 'log');
    colorbar; caxis([0 2]);
    xlabel('w1_{stiff} [mm]'); ylabel('A_z [mm]');
    title('w1_{stiff} effect (log scale)'); grid on;
    
    subplot(2,4,6);
    scatter(wm, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('w1_{mass} [mm]'); ylabel('A_z [mm]');
    title('w1_{mass} effect'); grid on;
    
    subplot(2,4,7);
    scatter(Ls, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('L [mm]'); ylabel('A_z [mm]');
    title('L (span) effect'); grid on;
    
    subplot(2,4,8);
    scatter(fa, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('f_{res} [Hz]'); ylabel('A_z [mm]');
    title('Resonance frequency effect'); grid on;
    
    % ========== 安全な保存方法 ==========
    fig_file = fullfile(out_dir, 'results_summary_enhanced.png');
    try
        exportgraphics(fig_handle, fig_file, 'Resolution', 300);
        fprintf('[SAVED] Enhanced figure: %s\n', fig_file);
    catch ME
        fprintf('[WARNING] exportgraphics failed: %s\n', ME.message);
        try
            print(fig_handle, fig_file, '-dpng', '-r300');
            fprintf('[SAVED] Enhanced figure (print): %s\n', fig_file);
        catch ME2
            fprintf('[ERROR] Could not save figure. Save manually.\n');
        end
    end
    
    % コンソール出力（同じ）
    fprintf('\n========== TOP 20 (Sorted by A_z) ==========\n');
    % ...（省略、元のコードと同じ）
end
